# Phase 1 - Hardened Compute Tile

## Goal

Phase 1 proves that a small RV32I compute tile can tolerate simple fault models
without adding extra CPU features. The focus is resilience: memory ECC, TMR for
selected architectural/control state, and fault-injection tests that show the
protection mechanisms doing useful work.

## CPU Scope

The core is a 32-bit RV32I multi-cycle CPU. It executes one instruction through
sequential control states instead of using a pipeline. This keeps the design
small enough to inspect while still exercising the real datapath pieces:

- program counter
- instruction decoder and control FSM
- ALU and ALU decoder
- register file
- instruction memory and data memory
- debug-facing halt, resume, register, PC, and program-buffer hooks

I am intentionally stopping Phase 1 at this point. The goal is not to keep adding
ISA extensions or performance features. The value of this phase is proving that
the hardened tile behaves correctly under injected faults.

## ECC Design

Instruction and data memory use SECDED-style ECC: single-error correction and
double-error detection. Each 32-bit data word is stored with check bits. On read,
the memory recomputes the syndrome:

- no error: return the word normally
- single-bit error: correct the word and raise a correction telemetry pulse
- double-bit error: raise a detection telemetry pulse

This models a common embedded reliability technique: correct the frequent simple
case, but do not silently hide uncorrectable corruption.

## TMR Design

Triple Modular Redundancy is used on selected state where a single bit flip could
change program behavior:

- program counter replicas
- register-file replicas
- main control FSM replicas
- instruction register/control path telemetry

The TMR blocks keep three copies and vote the visible output. If one replica is
corrupted, the majority value continues to drive the CPU. A disagreement pulse is
also exported so the system can count the event later.

## Fault-Injection Validation

The main Phase 1 testbench is `tb/core/tb_fault_inject.sv`. It injects faults
directly into internal memory/TMR replicas and checks that the CPU either masks
the error or reports it.

Current scenarios covered:

| Scenario | Expected behavior |
| --- | --- |
| Clean execution | Baseline register results match the test program |
| IMEM one-bit flip | ECC corrects the instruction word and execution continues |
| IMEM two-bit flip | ECC raises detection telemetry |
| DMEM one-bit flip | ECC corrects data on load |
| PC replica corruption | TMR voter masks the bad PC replica |
| Register-file replica corruption | TMR voter returns the majority value |
| FSM replica corruption | TMR voter masks the bad FSM state |

These tests produce the core demos needed for Phase 1:

- ECC single-bit correction demo
- ECC double-bit detection demo
- TMR masking demo
- initial fault campaign results

## ISS Status

The repository also contains a C instruction set simulator under `sim/`. It is
useful as an independent software model for RV32I behavior and for estimating
the cost of ECC/TMR in a space-hardened mode.

The remaining Phase 1 gap is full ISS-to-RTL co-simulation. The intended report
is:

1. run the same hex program on the ISS and RTL
2. emit comparable per-instruction traces
3. compare PC, instruction, register writes, memory accesses, and halt reason
4. record any mismatch with the first divergent instruction

Until that trace comparison is automated, ISS-to-RTL cross-check is documented
as in progress rather than complete.

## Design Decisions

The resilience features are visible through telemetry instead of being hidden
inside the core. That makes the behavior easy to test and prepares the design
for Phase 2, where the SoC health monitor counts these events.

The CPU remains simple and multi-cycle. This was a deliberate tradeoff: the
project is about reliability and debug integration, so clarity matters more than
pipeline performance at this stage.
