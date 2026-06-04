# Space Grade RISCV Soc

This project is a small FPGA SoC prototype for fault-tolerant onboard data
processing. The current focus is a simple RV32I CPU with ECC/TMR protection,
AXI4-Lite peripherals, debug access, and basic telemetry.

The goal is not to build a complex CPU. The goal is to build a resilient SoC
platform that can be tested, measured, and eventually run on FPGA hardware.

## Current Status

Phase 1 and Phase 2 are mostly implemented.

Phase 1: hardened compute tile
- RV32I multicycle CPU
- ECC-protected instruction/data memory
- TMR on PC, register file, instruction register, and control FSM
- fault injection testbench work
- C ISS models for baseline and space-hardened behavior

Phase 2: SoC integration
- AXI4-Lite crossbar
- IMEM and DMEM slaves
- UART TX slave
- Timer/watchdog slave
- Health monitor slave
- JTAG/DTM/Debug Module path
- top-level SoC integration for Arty A7 bring-up

## Architecture

```text
                    +----------------------+
                    |    RISC-V CPU        |
                    | + Debug Module       |
                    +----------+-----------+
                               |
                         AXI4-Lite Bus
                               |
 +-------------+--------------+---------------+---------------+
 |             |              |               |               |
IMEM(ECC)   DMEM(ECC)      UART        Timer/WDT      Health Monitor
                                                                  |
                                                     Telemetry Counters
                                                                  |
                                                            Interrupts
                                                                  |
                                                          DMA Controller
                                                                  |
                                                          AXI Stream
                                                                  |
                                                     +------------+
                                                     |
                                                FIR Accelerator
                                                     |
                                                Results → DMEM
```

The CPU fetches instructions directly from IMEM. Data accesses go through the
AXI4-Lite bus. Fault signals are collected by the health monitor.

## Repository Structure

```text
rtl/
  core/         CPU, ECC memory, TMR blocks
  bus/          AXI4-Lite crossbar and null slave
  peripheral/   UART, timer/WDT, health monitor, memory slaves
  debug/        debug module, program buffer, CDC bridge
  dtm/          JTAG debug transport module
  jtag/         TAP FSM
  system/       SoC top level
  package/      shared SystemVerilog packages

tb/             SystemVerilog testbenches
sim/            C ISS models and simulation results
sw/             small firmware examples
fpga/           constraints and FPGA scripts
docs/           design notes
synth/          synthesis scripts/outputs
```

## Useful Commands

Run RTL tests:

```sh
cd tb
make list
make run tb=tb_axi4_lite_uart_slave
```

Run the C simulators:

```sh
cd sim
make
./sim_baseline tests/test_all.hex
./sim_space tests/test_all.hex
```

Build the UART firmware example:

```sh
cd sw/uart_hello
make
```

## TODO

Near term:
- finish ISS vs RTL cross-check
- clean up fault injection validation
- confirm health monitor counters with tests
- connect/verify CPU interrupt path
- document the memory map clearly

Next phase:
- add one DMA engine
- add one FIR accelerator
- compare CPU-only vs DMA + accelerator

FPGA bring-up (ongoing): 
- generate bitstream for Arty A7
- check timing/resource reports
- use ILA for UART, reset, AXI, and health signals

Not planned:
- branch prediction
- out-of-order execution
- multiple accelerators
- PCIe or DDR controller work
