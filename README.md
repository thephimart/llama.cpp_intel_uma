# llama.cpp Intel UMA (Core Ultra / ARC iGPU)

This repository provides a Windows-first, Intel-optimized llama.cpp setup for Core Ultra systems using Intel ARC / XPU via SYCL.

**Focused testing** was performed on Intel Core Ultra 7 155H with 96GB RAM, with notes for Core Ultra 200 and 300 series systems.

> "This repo exists because Intel UMA deserves real tuning, not copy-pasted CUDA defaults."

| What this repo is | What this repo is not |
|-------------------|----------------------|
| Intel UMA–tuned | CUDA defaults copy-pasted |
| Thermal-aware | Max-fans benchmark chasing |
| Long-context focused | Short prompt demo rigs |

## Directory Layout

```
C:\llama.cpp
│
├─ configs\                      # Configuration files
│   ├─ ZZZ-Base-*.cfg          # Global base configurations
│   └─ *.cfg                   # Model-specific overrides
│
├─ sycl\                        # llama.cpp SYCL build
│   ├─ llama.cpp SYCL release
│   ├─ llama-server.exe
│   └─ llama-cli.exe
│
├─ docs\                        # Documentation
│   └─ guides\
│
├─ start-llama-server.ps1       # Main launcher script
├─ COMPACT.md                   # Context compaction guide
├─ llama.cpp model folder.lnk   # Model folder shortcut
├─ llama.ico                    # Icon
└─ README.md                    # This file
```

## Installation

### 1. Clone Repository
Clone this repo directly into `C:\`:
```bash
cd C:\
git clone https://github.com/thephimart/llama.cpp_intel_uma.git llama.cpp
```

### 2. Download llama.cpp SYCL Release
Get the latest release from:
[https://github.com/ggml-org/llama.cpp/releases](https://github.com/ggml-org/llama.cpp/releases)

Extract it to:
```
C:\llama.cpp\sycl
```

### 3. Models
Place GGUF models in:
```
%USERPROFILE%\AppData\Local\llama.cpp
```
> Or let Hugging Face downloads populate it automatically.

## Starting the Server

Run the interactive launcher:
```powershell
.\start-llama-server.ps1
```

### Creating a Shortcut

**Method 1: Desktop Shortcut**
1. Right-click `start-llama-server.ps1` in File Explorer
2. Select **Send to > Desktop (create shortcut)**
3. Right-click the new shortcut and select **Properties**
4. Click **Change Icon...** and browse to `C:\llama.cpp\llama.ico`
5. Rename the shortcut (e.g., "Llama Server")

**Method 2: Start Menu Pinning**

*Option A - From Desktop:*
1. Create the desktop shortcut using Method 1 above
2. Right-click the shortcut and select **Pin to Start**

*Option B - Direct to Start Menu:*
1. Press `Win + R`, type `shell:Start Menu` and press Enter
2. Navigate to `Programs` folder
3. Right-click and select **New > Shortcut**
4. Browse to `C:\llama.cpp\start-llama-server.ps1`
5. Name it "Llama Server" and click **Finish**
6. Right-click the shortcut > **Properties** > **Change Icon...**
7. Browse to `C:\llama.cpp\llama.ico` and apply

**Method 3: Taskbar Pinning**
1. First create a desktop shortcut using Method 1
2. Right-click the shortcut and select **Pin to taskbar**
3. Or drag the shortcut directly to the taskbar

> **Tip**: The provided `llama.ico` file gives your shortcut a professional appearance in the Start Menu, taskbar, and desktop.

### Configuration Workflow

The launcher automatically sets Intel SYCL environment variables and guides you through:

1. **Backend** - Shows selected backend (SYCL for Intel GPU/XPU)

2. **WebUI Toggle** 
   - Default: Disabled (`--no-webui`)
   - Option [1]: Enable web interface

3. **Network Mode**
   - [1] Local only (127.0.0.1) - Default
   - [2] Shared / LAN (0.0.0.0)

4. **Port Configuration**
   - Default: 11434 (Ollama-compatible)
   - Custom port supported

5. **Model Selection**
   - **[0]** No model (server-only mode)
   - **[H]** Hugging Face repository  
     (e.g., `unsloth/Qwen3-VL-30B-A3B-Thinking-GGUF:Q8_0`)
   - **[1-N]** Local GGUF files from `%USERPROFILE%\AppData\Local\llama.cpp`

6. **Base Config Selection**
   - **[0]** No base config (use llama.cpp defaults)
   - **[1]** ZZZ-Base-Config.cfg (default) - Standard chat/completion config
   - **[2]** ZZZ-Base-Embed-Config.cfg - Embedding-optimized config (no batch sizes)

7. **Runtime Config Override**
   - **[0]** No extra config
   - **[1-N]** Other `*.cfg` files (excluding `ZZZ-Base` files)

8. **Final Configuration Review**
   - Complete summary before launch
   - Option to restart configuration or proceed

### Validation & Safety

- Automatically validates `llama-server.exe` exists in `sycl\` directory
- Verifies `--mmproj` files exist before launching vision models
- Shows complete command line before execution
- Supports retry on configuration errors

## Configuration System

### Base Config (Required)

See [docs/core-ultra-155h-base-config.md](docs/core-ultra-155h-base-config.md) for detailed configuration explanations.

Current base configs are tuned aggressively for large-context and long-running workloads.
Earlier documentation referenced smaller batch sizes; those values have been superseded.

```
configs\ZZZ-Base-*.cfg
```

Three base configurations are available:

**1. ZZZ-Base-Config.cfg** (default) - Standard configuration for chat/completion models:
- **Threading** - 20 threads
- **Batch sizes** - 2048 batch / 2048 micro-batch
- **KV cache quantization** - q8_0 for both K and V
- **Parallelism** - Single parallel request
- **Cache behavior** - Automatic RAM cache (`-1`)
- Optimized for large-context, long-running inference

**2. ZZZ-Base-Config-Large-Context.cfg**
- Same as above, plus:
  - `--split-mode row`
  - `--no-context-shift`
- Intended for extreme context growth and compaction workflows

**3. ZZZ-Base-Embed-Config.cfg** - Optimized for embedding models:
- Same as base but without batch size constraints
- Ideal for embedding and retrieval workloads

> ℹBase configs are always applied first before per-model overrides.

### Per-Model Configs (Optional)

After selecting a model, you may apply one additional config file.

These are layered after the base config and are ideal for:
- **Context size overrides** - Custom context lengths
- **Model-specific batch tuning** - Per-model optimization
- **Vision models** - `--mmproj` configurations

## Intel SYCL / ARC Notes

The launcher automatically sets these environment variables:
```bash
SYCL_DEVICE_FILTER=level_zero:gpu
SYCL_UR_USE_LEVEL_ZERO_V2=1
GGML_SYCL_FORCE_CPU_KV=1
```
### KV Cache Placement (Intel UMA)

On Intel UMA systems, KV cache is explicitly forced to CPU memory:
```
GGML_SYCL_FORCE_CPU_KV=1
```
This is intentional and recommended.

**Why:**
- Prevents iGPU memory pressure at large context sizes
- Reduces UMA contention
- Improves stability with large batches and long-running sessions
- Produces more predictable performance on Meteor Lake

The iGPU is still used opportunistically for compute, but KV cache remains CPU-resident.

This enables:
- **ARC iGPU / XPU acceleration** - Hardware acceleration
- **Above 4GB Allocation** - Large model support
- **Flash Attention** - Required for KV cache quantization (for almost all models, there are exceptions)
- **Efficient UMA memory sharing** - Unified memory architecture

> **Important**: `--n-gpu-layers 0` is required in base config to enable flash attention.

## Documentation

Detailed configuration and tuning guides for Intel Core Ultra systems:

| Document | Description |
|----------|-------------|
| [Core Ultra 7 155H Base Config](docs/core-ultra-155h-base-config.md) | Complete base configuration guide for Intel Core Ultra 7 155H (Meteor Lake) |
| [Core Ultra 200 & 300 Series Notes](docs/core-ultra-200-and-300-series-notes.md) | Tuning guidance for Core Ultra 200-series (Lunar Lake) and 300-series (Arrow Lake) |

## Context Compaction

See [COMPACT.md](COMPACT.md) for the recommended context compaction prompt, designed for:

- **Long coding sessions**
- **Large-context models**
- **Iterative refinement workflows**

## License

MIT License — use it, fork it, break it, improve it.

---

**Happy inference!** If you find this useful, consider giving it a ⭐!
