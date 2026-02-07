llama.cpp Intel UMA (Core Ultra / ARC iGPU)

** Be warned the repo looks a mess, work in progress, but the actual tuning is solid for 155H **

This repository provides a Windows-first, Intel-optimized llama.cpp setup for Core Ultra systems using Intel ARC / XPU via SYCL.

Focused testing was performed on Intel Core Ultra 7 155H, but notes are included for Core Ultra 200 and 300 series systems.

“This repo exists because Intel UMA deserves real tuning, not copy-pasted CUDA defaults.”

Directory Layout
C:\llama.cpp
│
├─ configs\
│   ├─ ZZZ-Base-*.cfg          # Global base configuration
│   └─ per-model configs
│
├─ sycl\
│   └─ llama.cpp SYCL release
│       ├─ llama-server.exe
│       └─ llama-cli.exe
│
├─ doc\
│   └─ guides\
│
├─ start-llama-server.ps1
├─ COMPACT.md
├─ llama.cpp model folder.lnk
├─ llama.ico
└─ README.md

Installation

Clone this repo directly into C:\:

cd C:\
git clone https://github.com/thephimart/llama.cpp_intel_uma.git llama.cpp


Download the latest llama.cpp SYCL release
Extract it to:

C:\llama.cpp\sycl


Place GGUF models in:

%USERPROFILE%\AppData\Local\llama.cpp


(Or let Hugging Face downloads populate it automatically.)

Starting the Server

Run:

.\start-llama-server.ps1


The launcher will guide you through:

WebUI on/off

Local-only vs LAN access

Port selection

Model selection:

Local GGUF

Hugging Face repo

Or no model

Optional runtime config overlay

Configuration System
Base Config (Required)

A single base config is auto-detected:

configs\ZZZ-Base-*.cfg


This file defines:

Threading

Batch sizes

KV cache quantization

Parallelism

Cache behavior

It is always applied first.

Per-Model Configs (Optional)

After selecting a model, you may apply one additional config.

These are layered after the base config and are ideal for:

Context size overrides

Model-specific batch tuning

Vision (--mmproj) models

Intel SYCL / ARC Notes

The launcher sets:

SYCL_DEVICE_FILTER=level_zero:gpu
SYCL_UR_USE_LEVEL_ZERO_V2=1


This enables:

ARC iGPU / XPU acceleration

Flash Attention (required for KV cache quantization)

Efficient UMA memory sharing

Context Compaction

See:

COMPACT.md


For the recommended context compaction prompt, designed for:

Long coding sessions

Large-context models

Iterative refinement workflows

License

MIT License — use it, fork it, break it, improve it.


