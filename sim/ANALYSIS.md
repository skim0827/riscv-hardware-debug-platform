## What changes in the space model, and why 
**Context**: what kills electronics in space
In LEO or deep space, high-energy particles (protons, heavy ions from cosmic rays or solar events) pass through silicon and deposit charge. This can flip a bit in a memory cell or register — called a **Single Event Upset** (SEU). On Earth this is rare enough to ignore. In space it happens regularly and causes silent data corruption or crashes. Every space CPU must handle it.

1. EDAC on memory (Error Detection And Correction)
**What it is**: SEC-DED — **Single Error Correct, Double Error Detect**. A Hamming code variant. For every 32-bit data word stored, you compute 7 check bits and store 39 bits total. On read, you recompute the check bits and compare. If 1 bit flipped → correct it silently. If 2 bits flipped → detect it and raise a flag (you can't correct, but at least you know).

**In the industry** : The BAE Systems *RAD750* (used on Mars rovers, Hubble servicing), *LEON3/4* (ESA standard processor, used in BepiColombo, JUICE), and every space-grade SRAM chip implement SEC-DED. It's mandated by ECSS (European Cooperation for Space Standardization) for all space memory.

2. TMR on the register file
**What it is**: **Triple Modular Redundancy**. You keep 3 copies of every register. On every write, you write to all 3. On every read, you take a majority vote: if copy_A == copy_B, use that value; if not, copy_C is the tiebreaker. A single SEU flipping a bit in one copy is silently corrected.

**In the industry** : LEON4 uses TMR on its register windows option. Radiation-hardened flip-flops in ASICs are essentially single-cell TMR. For FPGAs in space (Xilinx Virtex-5QV, NanoXplore NG-Ultra), TMR is applied **at the synthesis level** with tools like *TMRTool* (similar to DFT insersion in the commercial IC flow but to make the chip fault-tolerant).

## Advanced techniques I'm deliberately skipping + and why
1. Memory scrubbing : A background process that periodically reads and rewrites every memory word to correct accumulated SEUs before two errors accumulate in the same word (making SEC-DED unable to correct). In real systems (*RAD750*, *LEON*) a scrub DMA runs in the background. Modeling this correctly requires a real time-sliced simulation loop and a separate scrub thread, complex enough to be a project on its own.
2. SEFI (Single Event Functional Interrupt) : A particle hits control logic (not data), causing the processor to **jump** to a wrong state. Requires modeling state machines as corruptible, which means adding probabilistic fault injection to your FSM, very specialised and niche for an ISS.
3. Radiation-hardened cell libraries (RHBD) : In real chip design, space ASICs use **enlarged** transistors, guard rings, and special cell layouts that are inherently more resistant to charge collection. This is a physical design / fab process concern, completely invisible at the ISS level.
4. SECDED with Chipkill / multi-bit ECC : Used for DRAM (not SRAM) where entire word lines can fail. Uses *BCH codes* or *Reed-Solomon* instead of Hamming. Much more complex coding theory, relevant to **DRAM controllers** not embedded processors.
5. Proton/heavy-ion cross-section modeling : Using *CREME96* or *OMERE* tools to compute actual **SEU rates** from an orbital environment (altitude, inclination, solar cycle). This is radiation physics, not computer architecture, a completely separate discipline.

## Watchdog 
A watchdog timer monitors real time. It fires if the system doesn't check in within N milliseconds. In hardware it's a countdown timer peripheral: software writes to a memory-mapped register to reset it, if it expires the CPU gets reset.
In a C ISS this doesn't translate. **The ISS has no real time**. It steps instruction by instruction as fast as your host CPU allows. There's no concept of "the CPU hung for 500ms" because the simulation never hangs independently of the host process.


## The Goal 
Measuring a quantified reliability/performance trade-off.

| Mode                | IPC   | Overhead    |
|---------------------|-------|-------------|
| Baseline multicycle | ~0.21 | —           |
| + EDAC              | ~0.19 | +9% cycles  |
| + TMR               | ~0.18 | +14% cycles |
| + Both              | ~0.17 | +20% cycles |
1. EDAC
    - **On a normal read**: you address memory → data out → done.
    - **On an EDAC read**: you address memory → data out → **recompute syndrome** → **compare with stored syndrome** → only now is the data trusted and usable. That syndrome check sits between the memory output and the point where the CPU can use the value. The CPU has to wait for it. That is the **cycle penalty** on every load instruction. On writes there's a smaller penalty. You must compute the check bits before storing, so the write can't complete until encoding is done.
    - So the overhead is localised, only **load** and **store** instructions pay it. Other instructions (ALU, branch, JAL) are untouched.

2. TMR 
    - The overhead comes from the **read** path, not the write path. Every instruction that reads a register (which is almost all of them) has to:
        - Read copy A, copy B, copy C
        - Run the majority voter: if A==B use A; if A==C use A; else use B
        - Only then pass the result to the ALU
    - That voter sits on the critical path between the register file output and the ALU input. **Every single instruction** pays it, not just loads.

3. Estimation 
TMR alone (+14%) is higher than EDAC alone (+9%). ***The reason***: EDAC only taxes memory instructions (~20-25% of a typical Dhrystone workload), while TMR taxes every instruction with a register read. The voter per instruction is a small penalty, but it applies universally.

## Haming Code 
32 data + **6 parity** + 1 overall parity = 39 bits 

$2r≥m+r+1$
- `m` = data bits 
- `r` = parity bits 

| Position | Purpose |
| -------- | ------- |
| 1        | P1      |
| 2        | P2      |
| 4        | P4      |
| 8        | P8      |
| 16       | P16     |
| 32       | P32     |

Hamming parity bits are placed at powers of two.

```
bit 63 ............. bit 39 | bit 38 ......... bit 32 | bit 31 ......... bit 0
        unused              |   7 ECC bits            |   32 data bits
                            |   (edac_encode returns)  |
``` 

| Syndrome | Overall parity | Meaning                       |
| -------- | -------------- | ----------------------------- |
| 0        | 0              | No error                      |
| nonzero  | 1              | **Single**-bit error          |
| nonzero  | 0              | **Double**-bit error          |
| 0        | 1              | Overall parity bit error only |

## Step space 
```
FETCH    → mem_read_w_space instead of mem_read_w

DECODE   → rs1 and rs2 values come through tmr_vote
           rd writes go to all 3 copies

EXECUTE  → identical switch, no changes here

MEMORY   → mem_read/write_space instead of baseline

CYCLES   → add_cycles same logic but +CYCLES_TMR_VOTE on every instruction
           +CYCLES_EDAC_ENCODE/DECODE already handled inside mem functions
```
## Result expected 
Mode            What it models                Question answered
──────────────────────────────────────────────────────────────────
Baseline        Plain multicycle core         What is my base IPC?
Space-hardened  Multicycle + EDAC/TMR/WDT     What does hardening cost?
Lockstep        Two baseline CPUs + comparator Can I detect faults?