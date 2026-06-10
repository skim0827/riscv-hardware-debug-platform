# Phase 2: SoC Integration

Goal: turn the hardened CPU tile into a small memory-mapped SoC.

Top level:

```text
rtl/system/soc_top.sv
```

## System Blocks

- RV32I CPU
- direct IMEM fetch path
- AXI4-Lite data crossbar
- DMEM slave
- UART TX slave
- timer/watchdog slave
- health monitor slave
- JTAG TAP, DTM, CDC bridge, and Debug Module

Instruction fetch goes directly to IMEM. Data accesses go through AXI4-Lite.

## Bus Layout

The data bus exposes:

| Slave | Purpose |
| --- | --- |
| DMEM | data memory with ECC telemetry |
| UART | transmit byte and busy status |
| Timer/WDT | timer IRQ and watchdog reset |
| Health | ECC/TMR counters and fault status |
| Null IMEM slot | returns decode error for invalid data access |

The IMEM null slot exists because instruction memory is not meant to be written
through the data bus.

## Health Monitor

The health monitor counts:

- IMEM/DMEM ECC corrections
- IMEM/DMEM ECC detections
- PC TMR disagreements
- FSM TMR disagreements
- register-file TMR disagreements
- instruction-register TMR disagreements

It also provides live status, latched IRQ status, IRQ mask, and counter clear.

## Watchdog

The watchdog reset only resets the CPU. The debug path stays alive so the system
can still be inspected after a watchdog event.

## FPGA Bring-Up Results

Target: Arty A7-35T (xc7a35ticsg324-1L), Vivado 2024

### Utilization (soc_top, post-synthesis, with TMR + ECC)

| Resource        | Used | Available | Util % |
|-----------------|------|-----------|--------|
| Slice LUTs      | 2069 | 20800     | 9.95   |
| Slice Registers | 1906 | 41600     | 4.58   |
| Block RAM (36K) |    2 | 50        | 4.00   |
| Bonded IOBs     |   13 | 210       | 6.19   |
| BUFG (clocks)   |    1 | 32        | 3.13   |

Primitive breakdown:

| Primitive | Count | What it is |
|-----------|-------|------------|
| FDCE      | 1877  | main FFs (async reset) — TMR copies, FSM, pipeline regs |
| FDRE      |   16  | sync-reset FFs |
| FDPE      |   13  | preset FFs |
| RAMB36E1  |    2  | ECC IMEM + ECC DMEM |
| LUT6/5/4… | 2069  | ALU, ECC codec, TMR voters, crossbar, decoders |
| MUXF7     |  256  | register-file read MUX tree |

Notes:
- BRAMs are counted separately from FFs — the 39-bit ECC arrays live in RAMB36E1, not in slice registers.
- Two black boxes (`u_ila_0_CV`, `dbg_hub_CV`) are the ILA and debug hub inserted for bring-up. These are not part of the design logic.
- Utilization is low, significant headroom for Phase 3 (DMA, FIR accelerator).

### Bring-Up Status

- "Hello FPGA" printing correctly over UART at 115200 baud
- ILA used to verify UART TX, AXI, and reset signals

## Current Gaps

- CPU interrupt connection
- full top-level SoC simulation signoff
- DMA register block
- firmware-style peripheral tests
