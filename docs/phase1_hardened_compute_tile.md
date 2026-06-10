# Phase 1: Hardened Compute Tile

Goal: prove the CPU tile can detect or mask simple faults.

This phase keeps the CPU small on purpose. The core is a multicycle RV32I design,
not a performance CPU. The interesting part is the hardening around it.

## Implemented

- RV32I multicycle CPU
- ECC-protected instruction and data memory
- TMR-protected PC
- TMR register file
- TMR main control FSM
- instruction-register TMR telemetry
- directed fault-injection testbench
- baseline and space-mode C ISS models

## ECC

Memory uses SECDED-style ECC:

- single-bit error: correct data and raise correction telemetry
- double-bit error: raise detection telemetry

This is used for IMEM and DMEM.

## TMR

Triple Modular Redundancy is used where a bad bit can change execution:

- PC
- register file
- main FSM
- instruction register path

Each block keeps three copies and votes the output. If one copy disagrees, the
voted value still drives the CPU and a telemetry pulse is raised.

## Validation

Main testbench:

```text
tb/core/tb_fault_inject.sv
```

Covered cases:

- clean program execution
- IMEM single-bit correction
- IMEM double-bit detection
- DMEM single-bit correction
- PC replica corruption
- register-file replica corruption
- FSM replica corruption

## ISS ↔ RTL Cross-Check

A C ISS (`sim/sim_baseline`) is used as a golden reference. Both the ISS and
RTL simulation run the same 5-instruction program and produce a PC + instruction
word trace. The traces are diffed automatically.

Run:

```sh
cd tb
make crosscheck
```

All 5 instructions matched (PASS). This confirms the RTL fetch and decode path
produces the same instruction sequence as the ISS for the tested program.


