# Intel Core Ultra 7 155H – Base Global llama.cpp Configuration

This document defines the baseline global llama.cpp configuration used for all testing and daily use on the Intel Core Ultra 7 155H (Meteor Lake) platform with 96GB RAM.

Per-model overrides (quant, context size, GPU layer tuning, etc.) are intentionally out of scope here and will live in separate, model-specific documents.

This config is designed to be safe, stable, and performant across a wide range of models, from small 1–2B instruction models to very large MoE systems.

**If you only set one configuration for this machine, this should be it.**

---

## Goals of This Configuration

- CPU-first execution with opportunistic iGPU assist
- Stable long-running performance (coding, document editing, large context)
- Predictable latency and smooth system behavior
- Minimal thermal stress
- Works well across many models, not tuned for just one

This is not a synthetic benchmark config. It is a "turn it on and forget it" setup.

This configuration treats prefill as an upfront cost and optimizes for uninterrupted generation — exactly how real work behaves.

---

## Base Global Configuration

```
--n-gpu-layers 0
--threads 20
--batch-size 2048
--ubatch-size 1024
--cache-type-k q8_0
--cache-type-v q8_0
--jinja
--parallel 1
--cache-ram -1
```

This configuration reflects **validated real-world stability**, not conservative defaults.

## Large Context Variant (Optional)

For extremely long sessions, the following variant is recommended:

```
--split-mode row
--no-context-shift
```

**Why this matters:**

- Disables implicit sliding window behavior
- Prevents unpredictable KV eviction
- Makes compaction explicit and controllable
- Improves determinism during long code iteration

This mode pairs best with:
- Manual compaction prompts
- `--cache-ram -1`
- Large batches

It trades flexibility for correctness — a good trade at large scale.

---

## Configuration Breakdown (Why These Values)

### `--n-gpu-layers 0`

This flag is doing more work than it looks like.

- Forces CPU-first execution
- Still allows llama.cpp to use the Intel Arc iGPU where supported
- Prevents partial or unstable GPU offloads on very large models
- **Enables Flash Attention, which is required for KV cache quantization**

That last point is important: Flash Attention is mandatory for q8_0 / quantized KV caches to work correctly and efficiently. Setting `--n-gpu-layers 0` ensures this path is available and stable.

**Notes from testing:**

- Most models will still opportunistically leverage the iGPU
- gpt-oss-20b is a known exception and runs CPU-only
- This mode gives the most consistent behavior across model sizes

### `--threads 20`

The Core Ultra 7 155H exposes 22 logical threads, but using all of them is not optimal.

**Empirical testing showed:**

- 18 and 20 threads tie for peak tokens/sec
- 20 threads has slightly better burst behavior
- Leaves the 2 low-power LP-E cores idle

**Why that matters:**

- Reduces scheduler contention
- Improves cache locality
- Avoids latency jitter from low-power cores
- Produces smoother long-running workloads

This setting fully utilizes P-cores and E-cores without overcommitting the CPU.

### `--batch-size 2048` / `--ubatch-size 1024`

This platform tolerates *much larger batches* than initially expected.

**Observed behavior from extended testing:**

- Large batches significantly reduce scheduling overhead
- Prefill becomes heavier, but:
  - Cache-ram amortizes it
  - Generation remains stable
- Tokens/sec degradation flattens as context grows
- Long uninterrupted generation benefits more than short prompts

**Why 2048 / 1024 works here:**

- 96GB UMA removes memory pressure
- Meteor Lake handles wide batches gracefully
- Large contexts (>20k) benefit disproportionately

This configuration favors:
- Long coding sessions
- Large document iteration
- Compaction-driven workflows

It is *not* optimized for short interactive prompts — and that is intentional.

## Context Scaling Behavior (Important)

This configuration has been validated up to ~40k active context with:

- Gradual, not exponential, throughput decline
- ~20–25% tokens/sec reduction at ~22–30k context
- Flattening degradation curve beyond that

Key observation:

> Prefill cost increases linearly, but generation cost grows sub-linearly.

This makes **compaction + cache-ram** the dominant strategy rather than aggressive context shifting.

### `--cache-type-k q8_0` / `--cache-type-v q8_0`

KV cache quantization is one of the biggest wins on this platform.

**Implementation note (Intel UMA):**

KV cache is explicitly forced to CPU memory via:

```
GGML_SYCL_FORCE_CPU_KV=1
```

This avoids UMA contention and improves stability with large batches and long contexts.
On Meteor Lake, this produces more consistent performance than allowing automatic
KV placement.

**Testing results:**

- Small models sometimes perform slightly better with K=bf16, V=q8_0
- bf16 has low overhead on this architecture
- Large models and MoE are consistently more efficient with:
  - K=q8_0
  - V=q8_0

**Why this is the global default:**

- Lower memory footprint
- Better cache residency at large context sizes
- Fewer cache misses
- More predictable performance under load

Unless you are only running small models, q8_0 / q8_0 is the right baseline.

### `--jinja`

Required for:

- Modern chat templates
- Tool calling
- Qwen / GLM / newer model formats

There is no measurable performance downside. This should always be enabled.

### `--parallel 1`

This enforces a single active inference slot.

**What this does not mean:**

- It does not block API usage
- It does not prevent multiple requests

**What it does mean:**

- Requests are serialized through one context
- Prevents KV cache duplication
- Avoids cache thrashing
- Keeps latency predictable

For long coding sessions, document iteration, and large contexts, this is exactly what you want.

### `--cache-ram -1`

Unlimited prompt cache in system RAM.

This flag provides outsized benefits, especially for large models and long contexts:

- Massive reduction in repeated prompt eval time
- Near-instant continuation after the first iteration
- Huge wins for:
  - Multi-prompt coding
  - Document revision
  - Long-running sessions
- No meaningful downside observed on small models

If you do frequent restarts or context compaction, this flag alone can completely change the experience.

---

## Power Management (Strongly Recommended)

Outside of llama.cpp itself:

**Set CPU maximum performance to ~80% in Windows Advanced Power Settings.**

**How to do this:**

1. Open the Start Menu and search for "Edit power plan"
2. Click "Change advanced power settings"
3. Expand "Processor power management" → "Maximum processor state"
4. Set both "On battery" and "Plugged in" to **80%**
5. Click "Apply" then "OK"

**Why:**

- Prevents thermal oscillation
- Reduces fan spikes
- Improves sustained throughput
- Extends hardware lifespan

**Trade-off:**

- Slightly lower peak tokens/sec
- Higher average tokens/sec over long runs
- Much smoother overall behavior

For real workloads, this is a net win.

---

## Models Used to Validate This Config

**Extensively tested:**

- Qwen3-Coder-30b-a3b-Instruct (Q4_K_XL)
- Qwen3-Coder-Next-80b-MoE
- LFM2.5-1.2b (thinking & instruct, bf16)

**Moderately tested:**

- GLM-4.6v-Flash (q5_K_M)
- gpt-oss-20b (MXFP4)
- GLM-4.7-Flash (q5_K_M)
- Trinity-Mini (q5_K_M)

**Additionally validated:**

- Falcon-H1R-7B (q5_K_M)
- Nemotron-Cascade-14B-Thinking (q5_K_M)
- Qwen3-VL-30B-A3B-Thinking (q5_K_M)
- Qwen3-1.7B (thinking/instruct, q5_K_M)
- Qwen3-42B-A3B-2507-Thinking-Abliterated-uncen-TOTAL-RECALL-v2-Medium-MASTER-CODER (MXFP4_MoE)

---

## Quantization Notes (High Level)

- **MXFP4** (when available) is preferred
  - Best data flow through the pipeline
  - Lower memory bandwidth pressure
- **q4_K_M** is the best general fallback
- **q5_K_M / q6_K_M** offer diminishing returns
  - Oversized quants often hurt real-world performance on this platform

**Rule of thumb:**

```
MXFP4 → q4_K_M → q5_K_M
```

---

## Summary

This base config turns the Core Ultra 7 155H into a quiet, stable, long-context workhorse rather than a short-burst benchmark machine.

It is intentionally conservative, predictable, and scalable — exactly what you want as a global default.

Per-model configs will layer on top of this, not fight it.
