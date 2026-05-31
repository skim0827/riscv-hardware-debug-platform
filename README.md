# RISC-V Hardware Debug Platform

A small RV32I hardware platform focused on reliability, debug visibility, and
SoC integration. The project starts with a hardened compute tile, then builds it
into an AXI4-Lite based system with memory-mapped peripherals and fault
telemetry.

## Project Flow

### Phase 1 - Hardened Compute Tile

Goal: prove that resilience mechanisms work before adding more system features.

Implemented:

- RV32I multi-cycle CPU core
- ECC-protected instruction and data memory
- TMR-protected PC, register-file/control state paths
- fault telemetry outputs for ECC and TMR events
- directed fault-injection testbench

In progress:

- automated ISS-to-RTL trace comparison
- more complete fault campaign reporting

Phase 1 intentionally stops here. The point is not to keep adding CPU features;
the point is to demonstrate correction, detection, and masking.

### Phase 2 - SoC Integration

Goal: turn the CPU tile into a small system.

Implemented or partially implemented:

- AXI4-Lite data crossbar
- direct IMEM instruction-fetch path
- DMEM AXI4-Lite slave
- UART TX AXI4-Lite slave
- Timer/watchdog AXI4-Lite slave
- Health monitor AXI4-Lite slave
- memory map package
- JTAG/DTM/Debug Module path integrated at top level

Still in progress:

- full top-level SoC signoff
- CPU interrupt connection
- DMA register block
- firmware-style peripheral access tests

## Architecture Summary

The CPU uses separate instruction and data interfaces:

- instruction fetch goes directly to IMEM
- data reads/writes go through an AXI4-Lite crossbar

The current SoC top level is `rtl/system/soc_top.sv`.

```
JTAG -> TAP -> DTM -> CDC -> Debug Module
                              |
                              v
                         RV32I CPU
                         /       \
                  IMEM direct   AXI4-Lite data crossbar
                                  |    |      |       |
                                DMEM  UART  Timer   Health
```

Fault telemetry is system-visible:

- ECC correction count
- ECC detection count
- TMR disagreement counts
- live fault status
- latched interrupt status

## Documentation

Start here:
- [Phase 1 - Hardened Compute Tile](docs/phase1_hardened_compute_tile.md)
- [Phase 2 - SoC Integration](docs/phase2_soc_integration.md)
- [Memory Map](docs/memory_map.md)

## Repository Layout

```text
rtl/
  core/        RV32I CPU, ECC memory, TMR blocks
  bus/         AXI4-Lite crossbar and null slave
  peripheral/ AXI4-Lite memory, UART, timer/WDT, health monitor
  debug/       Debug Module, program buffer, DMI CDC bridge
  dtm/         Debug Transport Module
  jtag/        JTAG TAP controller
  package/     shared SystemVerilog packages
  system/      SoC top level

tb/
  core/        CPU and fault-injection tests
  bus/         AXI4-Lite bus/peripheral tests
  peripheral/ UART, timer, health monitor tests
  debug/       Debug module tests
  dtm/         JTAG/DTM tests
  system/      integration tests

sim/
  src/         C ISS baseline and space-hardened models
  tests/       ISS hex programs
  results/     analysis outputs

docs/          concise project documentation
```

## Running Tests

Prerequisites:

- Verilator
- Make
- C/C++ compiler

Run RTL testbenches from `tb/`:

```sh
cd tb
make run tb=tb_axi4_lite_mem_slave
make run tb=tb_axi4_lite_uart_slave
make run tb=tb_axi4_lite_timer_slave
make run tb=tb_axi4_lite_health_slave
make run tb=tb_debug_module
make run tb=tb_dtm_top
```

`tb_fault_inject` is the main Phase 1 resilience regression, but it currently
needs an update while the CPU interface is being migrated to AXI4-Lite. See
[Verification Status](docs/verification_status.md) for the current test state.

List available testbenches:

```sh
cd tb
make list
```

Run the C ISS from `sim/`:

```sh
cd sim
make
./sim_baseline tests/test_all.hex
./sim_baseline --trace tests/test_all.hex
./sim_space tests/test_all.hex
```

## Technical Focus

This project is designed to show:

- hardware fault tolerance using ECC and TMR
- debug architecture using JTAG, DTM, and a RISC-V-style Debug Module
- clean memory-mapped SoC integration
- practical verification through directed SystemVerilog testbenches
- honest tracking of incomplete work, especially ISS-to-RTL co-simulation
