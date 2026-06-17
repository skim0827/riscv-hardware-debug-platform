# Phase 3: DMA + Accelerator

Goal: extend the SoC with a hardware accelerator and a DMA engine to offload bulk data movement from the CPU.

## Accelerator — FIR Filter

An 8-tap symmetric low-pass FIR filter, implemented as a standalone RTL block and wrapped behind an AXI4-Lite slave.

```text
rtl/accel/fir_filter.sv
rtl/peripheral/axi4_lite_fir_slave.sv
```

Filter parameters:

| Property | Value |
| --- | --- |
| Taps | 8 (symmetric) |
| Format | Q1.15 signed fixed-point |
| Coefficients | −53, 0, 1995, 4096, 4096, 1995, 0, −53 |
| Latency | 1 clock cycle |
| Saturation | clips to ±32767 on overflow |

The AXI slave exposes four registers:

| Offset | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x000` | `DATA_IN` | W | Write sample → push to FIR |
| `0x004` | `DATA_OUT` | R | bit[16] = valid flag, bits[15:0] = result |
| `0x008` | `STATUS` | R | bit[1] = busy, bit[0] = output valid |
| `0x00C` | `CTRL` | W | bit[0] = soft reset |

## DMA

The DMA engine lets the CPU program a transfer and step aside.

RTL: `rtl/peripheral/dma_ctrl.sv`

DMA has two AXI4-Lite interfaces:
- **Slave** (`DMA_BASE = 0x2000_3000`): CPU configures registers
- **Master**: DMA drives the bus independently to move data

### Register Map

| Offset | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x00` | `SRC_ADDR` | R/W | Source base address in DMEM |
| `0x04` | `DST_ADDR` | R/W | Destination base address in DMEM |
| `0x08` | `LEN` | R/W | Number of 32-bit words to transfer |
| `0x0C` | `CTRL` | R/W | `[0]` = start (SC), `[1]` = irq_en |
| `0x10` | `STATUS` | R | `[0]` = busy, `[1]` = done (W1C), `[2]` = error (W1C) |

**SC** (self-clearing): writing 1 to `CTRL[0]` starts the transfer; hardware clears it immediately.  
**W1C**: writing 1 to a STATUS bit clears it; used by the interrupt handler to acknowledge completion.

### Transfer Sequence (per word)

```
DMEM[cur_src]  →  FIR DATA_IN  →  poll STATUS[out_valid]
               →  FIR DATA_OUT  →  DMEM[cur_dst]
```

Repeats for `LEN` words. On completion, `STATUS[done]` is set and `dma_irq` is asserted (level) if `irq_en = 1`.  
On any AXI bus error (`SLVERR` / `DECERR`), the engine halts and sets `STATUS[error]`.

### Design Notes

- Single-beat (non-burst) transfers — deterministic latency, no reordering
- Interrupt is level-triggered: stays asserted until CPU clears `STATUS[1]` via W1C
- `set > clear` priority: if transfer completes in the same cycle as a CPU W1C, `done` is not lost
- FIR output is polled via STATUS rather than assumed ready, making the path correct regardless of FIR latency changes

## Benchmark

```text
sw/fir_benchmark/fir_benchmark.c
```

Runs two passes over 64 samples (8-tap), measures timer cycles for each:

| Path | Description |
| --- | --- |
| CPU-only | software shift register and MAC loop |
| HW accel | writes to `DATA_IN`, polls `STATUS`, reads `DATA_OUT` |

Outputs speedup ratio and verifies CPU and HW outputs agree within ±1 LSB.

## Validation

Standalone accelerator testbench:

```text
tb/accel/tb_fir.sv
```

Covers:
- direct FIR impulse response (h[0]…h[7] against exact expected values, ±1 LSB)
- same sequence through the AXI slave
- STATUS register idle check
- soft reset clears output register

Run:

```sh
cd tb
make tb=tb_fir
```

## Current Gaps

- Crossbar not yet expanded to 2 masters (CPU + DMA)
- DMA not yet wired into `soc_top.sv`
- End-to-end integration testbench (`tb_fir_dma.sv`) not yet written
- Benchmark numbers pending full DMA integration
