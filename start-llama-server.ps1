# ================= CONFIG =================
$BasePath    = "C:\llama.cpp"
$BackendName = "SYCL (Intel GPU / XPU)"
$SyclPath    = Join-Path $BasePath "sycl"
$LlamaPath   = $SyclPath
$ConfigPath  = Join-Path $BasePath "configs"
$DefaultPort = 11434
$LlamaCache  = "$env:USERPROFILE\AppData\Local\llama.cpp"
$env:SYCL_DEVICE_FILTER="level_zero:gpu"
$env:SYCL_UR_USE_LEVEL_ZERO_V2 = "1"
#$env:SYCL_UR_TRACE="1"
# ==========================================

do {
    Clear-Host
    Write-Host "========================================="
    Write-Host "       llama.cpp Server Launcher"
    Write-Host "========================================="

    # ---------- Backend ----------
    Write-Host "`nSelected backend: $BackendName`n"

    # ---------- WebUI ----------
    Write-Host "Enable WebUI?"
    Write-Host "  [1] Yes"
    Write-Host "  [2] No (default)"
    $webuiChoice = Read-Host "Enter choice [1/2]"

    $EnableWebUI = $false
    if ($webuiChoice -eq "1") {
        $EnableWebUI = $true
        Write-Host "`nEnable WebUI: Yes`n"
    } else {
        Write-Host "`nEnable WebUI: No`n"
    }

    # ---------- Local / Shared ----------
    Write-Host "Choose server mode:"
    Write-Host "  [1] Local only (127.0.0.1)"
    Write-Host "  [2] Shared / LAN (0.0.0.0)"
    $mode = Read-Host "Enter choice [1/2] (default 1)"

    if ($mode -eq "2") {
        $HostAddr = "0.0.0.0"
        $ModeName = "SHARED"
    } else {
        $HostAddr = "127.0.0.1"
        $ModeName = "LOCAL"
    }

    Write-Host "`nSelected mode: $ModeName`n"

    # ---------- Port ----------
    $port = Read-Host "Enter port number (default: $DefaultPort)"
    if (-not $port) { $port = $DefaultPort }

    # ---------- Model selection ----------
    Write-Host "`nAvailable models:"
    Write-Host "  [0] Load no model"
    Write-Host "  [H] Enter Hugging Face repo`n"

    $Models = @()
    if (Test-Path $LlamaCache) {
        $Models = Get-ChildItem $LlamaCache -Filter *.gguf |
            Where-Object { $_.Name -notmatch "mmproj" } |
            Sort-Object Name
    }

    for ($i = 0; $i -lt $Models.Count; $i++) {
        Write-Host "  [$($i+1)] $($Models[$i].Name)"
    }

    $choice = Read-Host "`nSelect model number, [H], or [0]"

    $Model = $null
    $ModelMode = "NONE"

    if ($choice -eq "0") {
        $ModelMode = "NONE"
    }
    elseif ($choice -match '^[Hh]$') {
        $Model = (Read-Host "Enter HF repo (e.g. unsloth/Qwen3-VL-30B-A3B-Thinking-GGUF:Q8_0)").Trim()
        if ($Model) { $ModelMode = "HF" }
    }
    elseif ($choice -match '^\d+$') {
        $idx = [int]$choice
        if ($idx -ge 1 -and $idx -le $Models.Count) {
            $Model = $Models[$idx - 1].FullName
            $ModelMode = "GGUF"
        }
    }

    # ---------- Base Config Selection ----------
    Write-Host "`nBase config preset:"
    Write-Host "  [0] No base config (use llama.cpp defaults)`n"

    $BaseConfigs = @()
    if (Test-Path $ConfigPath) {
        $BaseConfigs = Get-ChildItem $ConfigPath -Filter "ZZZ-Base-*.cfg" |
            Sort-Object Name
    }

    for ($i = 0; $i -lt $BaseConfigs.Count; $i++) {
        $suffix = if ($i -eq 0) { " (default)" } else { "" }
        Write-Host "  [$($i+1)] $($BaseConfigs[$i].Name)$suffix"
    }

    $baseChoice = Read-Host "`nSelect base config number or [0] (default: 1)"
    if (-not $baseChoice) { $baseChoice = "1" }

    $BaseArgs = @()
    $BaseConfig = $null

    if ($baseChoice -match '^\d+$') {
        $baseIdx = [int]$baseChoice
        if ($baseIdx -ge 1 -and $baseIdx -le $BaseConfigs.Count) {
            $BaseConfig = $BaseConfigs[$baseIdx - 1]
            Write-Host "`nUsing base config: $($BaseConfig.Name)`n"

            Get-Content $BaseConfig.FullName | ForEach-Object {
                $line = $_.Trim()
                if ($line -and -not $line.StartsWith("#")) {
                    $BaseArgs += ($line -split '\s+')
                }
            }
        }
    }

    # ---------- Optional runtime config ----------
    Write-Host "Optional runtime config:"
    Write-Host "  [0] No extra config`n"

    $Configs = @()
    if (Test-Path $ConfigPath) {
        $Configs = Get-ChildItem $ConfigPath -Filter "*.cfg" |
            Where-Object { $_.Name -notmatch '^ZZZ-Base' }
    }

    for ($i = 0; $i -lt $Configs.Count; $i++) {
        Write-Host "  [$($i+1)] $($Configs[$i].Name)"
    }

    $cfgChoice = Read-Host "`nSelect config number or [0]"

    $ExtraArgs = @()
    $CFG_FILE = $null

    if ($cfgChoice -match '^\d+$') {
        $cfgIdx = [int]$cfgChoice
        if ($cfgIdx -ge 1 -and $cfgIdx -le $Configs.Count) {
            $CFG_FILE = $Configs[$cfgIdx - 1].FullName
            Write-Host "Using config file: $CFG_FILE"

            Get-Content $CFG_FILE | ForEach-Object {
                $line = $_.Trim()
                if ($line -and -not $line.StartsWith("#")) {
                    $ExtraArgs += ($line -split '\s+')
                }
            }
        }
    }

    # ---------- Validate EXE ----------
    $Exe = Join-Path $LlamaPath "llama-server.exe"
    if (-not (Test-Path $Exe)) {
        Write-Error "llama-server.exe not found in $LlamaPath"
        exit 1
    }

    # ---------- Validate mmproj ----------
    $mmproj = $null
    for ($i = 0; $i -lt $ExtraArgs.Count; $i++) {
        if ($ExtraArgs[$i] -eq "--mmproj" -and ($i + 1) -lt $ExtraArgs.Count) {
            $mmproj = $ExtraArgs[$i + 1]
            break
        }
    }

    if ($mmproj -and -not (Test-Path $mmproj)) {
        Write-Error "ERROR: mmproj file not found: $mmproj"
        Read-Host "Press Enter to exit"
        exit 1
    }

    # ---------- Final Summary ----------
    Write-Host "`n========================================="
    Write-Host "Final launch configuration:"
    Write-Host "  Backend : $BackendName"
    Write-Host "  WebUI   : $(if ($EnableWebUI) { 'ENABLED' } else { 'DISABLED (--no-webui)' })"
    Write-Host "  Host    : $HostAddr"
    Write-Host "  Port    : $port"
    Write-Host "  Model   : $(if ($Model) { $Model } else { 'none' })"
    Write-Host "  BaseCfg : $(if ($BaseConfig) { $BaseConfig.Name } else { 'none (defaults)' })"
    Write-Host "  ExtraCfg: $(if ($CFG_FILE) { (Split-Path $CFG_FILE -Leaf) } else { 'none' })"
    Write-Host "========================================="

    Write-Host "`nProceed with launch?"
    Write-Host "  [1] Yes, launch"
    Write-Host "  [2] No, start over"

    $confirm = Read-Host "Enter choice [1/2] (default: 1)"
    if (-not $confirm) { $confirm = "1" }

    if ($confirm -ne "1") {
        Write-Host "`nRestarting configuration..."
        Start-Sleep -Milliseconds 600
        continue
    }

    # ---------- Launch ----------
    Write-Host "`nLaunching llama-server...`n"
    Write-Host "`nCommand line:"
    Write-Host "$Exe $($cmd -join ' ')"

    $cmd = @()

    if (-not $EnableWebUI) {
        $cmd += "--no-webui"
    }

    $cmd += @(
        "--host", $HostAddr,
        "--port", $port
    )

    switch ($ModelMode) {
        "GGUF" { $cmd += @("--model", $Model) }
        "HF"   { $cmd += @("-hf", $Model) }
    }

    # Base config FIRST, model config SECOND
    $cmd += $BaseArgs
    $cmd += $ExtraArgs

    & $Exe @cmd

break
} while ($true)

Write-Host "`nServer process ended."
Pause
