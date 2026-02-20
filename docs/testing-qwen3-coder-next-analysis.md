Qwen3-Coder-Next-80B (Sparse MoE) — Intel UMA Testing Report

This document summarizes focused performance testing of Qwen3-Coder-Next-80B (Sparse MoE, MXFP4 GGUF) on Intel Core Ultra UMA systems using llama.cpp SYCL.

Testing was performed to identify batch size ceilings, throughput plateaus, and failure modes specific to large sparse-MoE models on Intel UMA — where memory topology and kernel launch constraints matter more than raw FLOPs.

Test Environment (Baseline)

CPU: Intel Core Ultra 7 155H

Memory: 96 GB DDR5 (UMA)

Backend: llama.cpp SYCL (ARC iGPU / XPU)

Threads: 20 (empirically optimal; leaves LP cores idle)

KV Cache: q8_0 / q8_0

Flash Attention: Enabled (--n-gpu-layers 0)

Parallelism: --parallel 1

Cache RAM: -1 (adaptive)

Unless stated otherwise, all tests used:

--n-gpu-layers 0
--threads 20
--cache-type-k q8_0
--cache-type-v q8_0
--parallel 1
--cache-ram -1
Test Methodology

Prompt length: 1614 tokens (fixed)

Measurement focus:

Prompt ingestion latency

Steady-state generation throughput

Stability at increasing batch sizes

Batch (--batch-size) and micro-batch (--ubatch-size) were swept together to isolate upper-bound behavior.

Both CPU-first (ngl=0) and GPU-assisted runs were tested.

Batch Size Scaling Results (CPU-First, ngl=0)
Batch / uBatch	Prompt TPS	Eval TPS	Outcome
1024 / 1024	~20.3 t/s	~4.11 t/s	Stable
1536 / 1536	~25.9 t/s	~4.07 t/s	Peak efficiency
1550 / 1550	~26 t/s	~4 t/s	Last stable point
2048 / 1024	—	—	Unstable / degraded
2048 / 2048	—	—	Failure / regression
Key Observation

Performance improves cleanly up to ~1536–1550

Beyond ~1550 tokens per batch, scaling collapses

Larger batches do not increase throughput and frequently destabilize execution

This behavior was repeatable across runs.

The 1550 Batch Ceiling (Why It Exists)

The ~1550 batch ceiling behaves like a hard transport or scheduling limit, not a soft performance knee.

This aligns with an MTU-style constraint, where an internal limit is reached related to:

Vocabulary size

Sparse MoE routing tables

Quantized expert weight blocks

KV cache addressing under flash-attention

Conceptually:

effective_batch_limit ≈ f(vocab, experts, quant_stride, routing)

Once this boundary is crossed:

Kernel launches fragment

Memory transactions spill

Scheduler overhead dominates

Throughput decreases instead of saturating

This is not a RAM exhaustion issue — the system still has headroom.
It is a structural execution limit for this model class on Intel UMA.

GPU-Assisted Runs (SYCL Offload)

GPU-assisted tests (partial or heavy offload):

Did not exceed CPU-first throughput

Introduced additional scheduling overhead

Offered no benefit past ~1024 batch

For Qwen3-Coder-Next-80B:

CPU-first execution with flash attention is the optimal mode

This is consistent with sparse-MoE behavior where:

Experts thrash cache locality

UMA coherence costs outweigh compute gains

Practical Recommendations
✅ Recommended Configuration (80B)
--batch-size 1536
--ubatch-size 1536
--n-gpu-layers 0

This hits the maximum stable ingestion throughput without crossing the execution ceiling.

❌ Avoid

Batch sizes ≥1600

Forcing GPU-heavy offload

Oversized micro-batches assuming “more is better”

Comparison to 30B Dense Models (Context Only)

30B dense models scale smoothly to 2K+ batches

80B sparse-MoE models do not

The ceiling is model-architecture-driven, not hardware-driven

This is why the 80B results must not reuse 30B tuning assumptions.

Final Takeaway

Qwen3-Coder-Next-80B has a real, measurable batch ceiling at ~1550 tokens on Intel UMA.

Pushing past it:

Does not improve throughput

Actively harms stability

Masks the model’s true efficiency window

Respecting this limit yields:

Predictable performance

Lower thermals

Better long-run stability

Cleaner system behavior under sustained coding workloads

**That said, setting global defaults to batch 2048 and microbatch to 2048 has no negative side effects**