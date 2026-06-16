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

CPU programs:
- source address (DMEM)
- destination address (FIR slave or output buffer)
- transfer size

DMA handles:
- reading samples from DMEM
- feeding `DATA_IN` on the FIR slave
- writing results back to DMEM
- asserting a completion interrupt to the CPU

DMA registers live at `0x2000_3000`. RTL is in progress.

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

- DMA RTL not yet written
- DMA-fed accelerator path not tested end-to-end
- benchmark numbers pending DMA integration (current HW path is CPU-polled, not DMA-driven)
- interrupt wiring from DMA to CPU
