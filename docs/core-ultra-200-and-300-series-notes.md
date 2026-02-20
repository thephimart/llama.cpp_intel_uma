# Core Ultra 200 & 300 Series Tuning Notes

This document covers what carries over unchanged versus what likely shifts for Core Ultra 200-series (Lunar Lake) and 300-series (Arrow Lake w/ Arc iGPU).

## TL;DR

- Core ideas carry over: CPU-first, KV cache quant, Flash Attention, cache-ram, parallel=1
- Threading will change
- Batch / ubatch plateaus will move
- UMA behavior improves, especially on Lunar Lake
- You will almost certainly tolerate *equal or larger batches* than 155H, especially on Lunar Lake.
- Not a rewrite — more like a retune.

---

## What Transfers Almost 1:1

These are architecture-agnostic wins:

### ✔ `--cache-ram -1`

Still huge. Maybe even bigger wins due to:

- Faster memory controllers
- Improved LLC / fabric
- Better iGPU memory coherency

### ✔ KV Cache Quantization (`q8_0`)

Still the right call for:

- Large contexts
- Long sessions
- MoE models

### ✔ Flash Attention requirement

Unchanged.

- Still required for KV quant
- `--n-gpu-layers 0` remains the safest way to ensure it

### ✔ `--parallel 1`

Still optimal for:

- Long coding sessions
- Large context accumulation
- Avoiding KV duplication

---

## Where Things Start to Diverge

### 1. Thread Count (Big Change)

#### Core Ultra 200 (Lunar Lake)

- No E-cores
- Fewer total threads
- Much stronger per-core IPC

**Expect:**

- Best performance closer to N-1 or N-2 threads
- No need to "leave LP cores alone" — they're gone
- Thread oversubscription hurts more here

If it's an 8P / 16T layout:

```
--threads 14 or 15
```

will likely beat `--threads 16`.

#### Core Ultra 300 (Arrow Lake)

- P + E + new LP behavior again
- Higher core counts
- More aggressive power management

Similar rule to 155H:

- Don't max threads
- Leave scheduler headroom
- Expect sweet spot around ~80–85% of logical threads

### 2. Batch / UBatch Sizes (More Important Than Expected)

155H validated stable operation at:

```
batch 2048
ubatch 1024
```

On Core Ultra 200 / 300:

**Expect:**

- Equal or higher batch ceilings
- Lower relative prefill cost
- Even flatter context scaling curves

Especially on Lunar Lake:

- Improved memory fabric
- Stronger UMA coherency
- Reduced CPU ↔ iGPU stalls

Large batches become *more correct*, not less.

### 3. UMA & iGPU Interaction (Quiet but Important Upgrade)

This is the sleeper improvement.

**Lunar Lake especially:**

- Much tighter CPU ↔ iGPU memory coupling
- Lower copy overhead
- Better shared cache behavior

**What that means for llama.cpp:**

- CPU-first with opportunistic iGPU assist becomes more effective
- Less penalty for larger batches
- Fewer stalls during prefill

Your current philosophy:

> "CPU leads, GPU assists quietly"

fits Lunar Lake perfectly.

---

## `--n-gpu-layers 0` Still the Right Default

Even on newer ARC iGPUs:

**Why this still works best:**

- Avoids fragile partial offload heuristics
- Keeps Flash Attention paths clean
- Lets llama.cpp decide when the iGPU actually helps
- Prevents large-model failures or weird fallback behavior

If anything, newer ARC makes this more viable, not less.

---

## What Might Change Later (Optional Tweaks)

Some models may benefit from:

- Different KV quant mix (bf16/q8) on small models only
- Larger L3 caches may reduce sensitivity to ubatch tuning

But those belong in per-model overrides, not the global config.
KV cache is still recommended on CPU by default, though future ARC generations may revisit this assumption.

---

## Big Picture Takeaway

155H config is philosophically correct, just not empirically tuned for 200/300 series.

**On Core Ultra 200 / 300:**

- You'll retune the numbers
- You won't change the approach
