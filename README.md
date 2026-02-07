llama.cpp Intel UMA (Windows / Core Ultra Focus)

This repository contains a Windows-focused llama.cpp setup and tuning guide, tested primarily on Intel Core Ultra 7 155H (Meteor Lake, UMA) systems using the SYCL backend.

The goal is simple:

sane defaults

reproducible performance

minimal friction for running large GGUF models on Intel UMA hardware

This repo provides:

a base global config plus per-model configs

a PowerShell launch script

documentation for tuning on Intel Core Ultra systems

a clean directory layout you can clone directly to C:\

Tested Hardware Focus

Primary testing platform:

Intel Core Ultra 7 155H

P-cores + E-cores fully utilized

LP-E cores intentionally left unused

Intel ARC iGPU (UMA)

Windows 11

llama.cpp SYCL releases

Other Intel Core Ultra systems may work well, but settings here are tuned and validated against the 155H specifically. See /docs/guides/core_ultra_200_and_300_series_notes.md for forward-looking notes on newer generations.

Repository Layout

Expected directory structure after setup:

C:\llama.cpp
│
├─ configs
│   ├─ base.cfg
│   └─ per-model configs (.cfg)
│
├─ sycl
│   └─ llama.cpp SYCL release files
│      (llama-cli.exe, llama-server.exe, etc)
│
├─ docs
│   └─ guides
│
├─ README.md
├─ COMPACT.md
├─ start-llama-server.ps1
├─ llama.cpp model folder.lnk
├─ llama.ico
└─ LICENSE

Quick Start (Windows)
1. Clone the Repository

Open PowerShell and run:

cd C:\
git clone https://github.com/thephimart/llama.cpp_intel_uma.git llama.cpp


This clones the repo directly into:

C:\llama.cpp

2. Download llama.cpp SYCL Release

Download the latest llama.cpp SYCL Windows release

Extract it into:

C:\llama.cpp\sycl


After extraction, you should see files like:

llama-cli.exe

llama-server.exe

inside C:\llama.cpp\sycl

3. Models Folder

This repo includes a shortcut:

llama.cpp model folder.lnk

It points to your models directory using environment variables (no hardcoded paths).
Place your GGUF models there, or update the shortcut if you prefer a different location.

4. Start the Server

Run the PowerShell script:

.\start-llama-server.ps1


This script:

loads the base global config

applies sane defaults for Intel UMA

launches llama-server.exe with SYCL support

You can modify or extend this script once per-model configs are added.

Base Global Config Philosophy

The base config is designed to:

favor CPU + iGPU cooperation

keep thermals under control

avoid pathological memory pressure

perform well for large context, long-running sessions

Highlights:

--n-gpu-layers 0
Enables CPU-first scheduling while still allowing iGPU offload, and is required for Flash Attention + KV cache quantization.

tuned thread count for P/E cores

high but stable batch / ubatch sizes

aggressive KV cache quantization for large models

--cache-ram -1 for massive wins on long-running workloads

Full details are documented in /docs/guides/.

COMPACT.md

COMPACT.md is an in-progress prompt and workflow for aggressively squeezing context during long sessions (coding, refactors, document iteration).

It’s not finalized — treat it as experimental.

Notes on Other Intel Core Ultra Generations

While this repo is focused on the 155H, newer Intel Core Ultra 200/300 series systems may benefit from:

different batch size plateaus

altered UMA behavior

improved iGPU scheduling

See:

/docs/guides/core_ultra_200_and_300_series_notes.md

License

MIT License — use it, fork it, break it, improve it.
