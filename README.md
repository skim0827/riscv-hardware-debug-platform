# RISC-V Hardware Debug Platform

A fault-tolerant RV32M SoC prototype targeting FPGA (Arty A7). The focus is resilience, observability, and hardware acceleration — not CPU complexity.

## Status

| Phase | Description | Status |
| --- | --- | --- |
| 1 | Hardened compute tile | Done |
| 2 | SoC integration + FPGA bring-up | Done |
| 3 | DMA + FIR accelerator | In progress |

## Architecture

```
CPU (RV32I + Debug Module)
│
└── AXI4-Lite Crossbar (2 masters: CPU, DMA)
      ├── IMEM (ECC)          0x0000_0000
      ├── DMEM (ECC)          0x1000_0000
      ├── UART TX             0x2000_0000
      ├── Timer / WDT         0x2000_1000
      ├── Health Monitor      0x2000_2000
      ├── DMA Controller      0x2000_3000
      └── FIR Accelerator     0x2000_4000
```

## TODO

Phase 1 — hardened compute:
- ~~RV32I multicycle CPU~~
- ~~ECC on IMEM and DMEM~~
- ~~TMR on PC, register file, instruction register, control FSM~~
- ~~fault injection testbench~~
- ~~ISS vs RTL cross-check~~ (`make crosscheck`)

Phase 2 — SoC integration:
- ~~AXI4-Lite crossbar, IMEM/DMEM slaves~~
- ~~UART, Timer/watchdog, Health Monitor peripherals~~
- ~~JTAG → DTM → Debug Module path~~
- ~~FPGA bring-up on Arty A7~~ (Hello UART printing, ILA captures done)
- connect and verify CPU interrupt path

Phase 3 — DMA + FIR accelerator:
- ~~8-tap FIR filter RTL + AXI4-Lite slave~~
- ~~DMA controller RTL + wired into soc_top~~
- ~~crossbar expanded to 2 masters (CPU + DMA)~~
- end-to-end integration testbench (`tb_fir_dma.sv`)
- run benchmark: CPU-only FIR vs DMA + HW accelerator

## Repository Layout

```
rtl/
  core/         CPU, ECC memory, TMR blocks
  bus/          AXI4-Lite crossbar
  peripheral/   UART, timer/WDT, health monitor, DMA controller, FIR slave
  accel/        FIR filter RTL
  debug/        debug module, program buffer, CDC bridge
  dtm/          JTAG debug transport module
  jtag/         TAP FSM
  system/       SoC top level
  package/      shared packages

tb/             SystemVerilog testbenches
sim/            C ISS models
sw/             firmware (uart_hello, fir_benchmark)
fpga/           Arty A7 constraints and scripts
docs/           design notes and memory map
```

## Commands

```sh
# run any RTL testbench
cd tb && make tb=<name>

# FIR accelerator testbench
cd tb && make tb=tb_fir

# ISS vs RTL cross-check
cd tb && make crosscheck

# C ISS models
cd sim && make && ./sim_space tests/test_all.hex
```

## Documentation

- [Phase 1](docs/phase1_hardened_compute_tile.md)
- [Phase 2](docs/phase2_soc_integration.md)
- [Phase 3](docs/phase3_dma_accelerator.md)
- [Memory Map](docs/memory_map.md)
