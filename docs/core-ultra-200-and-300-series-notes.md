what carries over unchanged vs what likely shifts for Core Ultra 200-series (Lunar Lake) and 300-series (Arrow Lake w/ Arc iGPU).

TL;DR

Core ideas carry over: CPU-first, KV cache quant, Flash Attention, cache-ram, parallel=1

Threading will change

Batch / ubatch plateaus will move

UMA behavior improves, especially on Lunar Lake

You’ll probably end up with slightly larger batches on 200/300 than 155H

Not a rewrite — more like a retune.

What Transfers Almost 1:1

These are architecture-agnostic wins:

✔ --cache-ram -1

Still huge. Maybe even bigger wins due to:

Faster memory controllers

Improved LLC / fabric

Better iGPU memory coherency

✔ KV Cache Quantization (q8_0)

Still the right call for:

Large contexts

Long sessions

MoE models

✔ Flash Attention requirement

Unchanged.

Still required for KV quant

--n-gpu-layers 0 remains the safest way to ensure it

✔ --parallel 1

Still optimal for:

Long coding sessions

Large context accumulation

Avoiding KV duplication

Where Things Start to Diverge
1. Thread Count (Big Change)
Core Ultra 200 (Lunar Lake)

No E-cores

Fewer total threads

Much stronger per-core IPC

Expect:

Best performance closer to N-1 or N-2 threads

No need to “leave LP cores alone” — they’re gone

Thread oversubscription hurts more here

If it’s an 8P / 16T layout:

--threads 14 or 15


will likely beat --threads 16.

Core Ultra 300 (Arrow Lake)

P + E + new LP behavior again

Higher core counts

More aggressive power management

Similar rule to 155H:

Don’t max threads

Leave scheduler headroom

Expect sweet spot around ~80–85% of logical threads

2. Batch / UBatch Sizes (Moderate Change)

This is where ARC + memory improvements start to matter.

On 155H

You found:

batch 256
ubatch 128


near the top of the plateau.

On 200 / 300 Series

Expect:

Higher sustained memory bandwidth

Lower memory latency

Better UMA coherency with iGPU

That usually shifts the plateau upward, not sideways.

Likely new ranges:

--batch-size 320–384
--ubatch-size 160–192


Key point:

You won’t get dramatically higher peak t/s,
but you’ll get flatter degradation curves as context grows.

That matters a lot more in real use.

3. UMA & iGPU Interaction (Quiet but Important Upgrade)

This is the sleeper improvement.

Lunar Lake especially:

Much tighter CPU ↔ iGPU memory coupling

Lower copy overhead

Better shared cache behavior

What that means for llama.cpp:

CPU-first with opportunistic iGPU assist becomes more effective

Less penalty for larger batches

Fewer stalls during prefill

Your current philosophy:

“CPU leads, GPU assists quietly”

fits Lunar Lake perfectly.

--n-gpu-layers 0 Still the Right Default

Even on newer ARC iGPUs:

Why this still works best:

Avoids fragile partial offload heuristics

Keeps Flash Attention paths clean

Lets llama.cpp decide when the iGPU actually helps

Prevents large-model failures or weird fallback behavior

If anything, newer ARC makes this more viable, not less.

What Might Change Later (Optional Tweaks)

Not base-config material yet, but worth noting:

Some models may benefit from:

Slightly higher ubatch than batch / 2

Different KV quant mix (bf16/q8) on small models only

Larger L3 caches may reduce sensitivity to ubatch tuning

But those belong in per-model overrides, not the global config.

Big Picture Takeaway

Your 155H config is philosophically correct, not just empirically tuned.

On Core Ultra 200 / 300:

You’ll retune the numbers

You won’t change the approach

That’s exactly what you want in a base global config.
