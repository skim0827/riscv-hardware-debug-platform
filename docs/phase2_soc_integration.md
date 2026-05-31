# Phase 2 - SoC Integration

## Goal

Phase 2 turns the hardened CPU tile into a small SoC. The CPU moves from local
memory-style connections toward memory-mapped AXI4-Lite access, with real
peripherals around it.

The current top level is `rtl/system/soc_top.sv`.

## System Shape

The SoC contains:

- RV32I CPU core
- JTAG TAP, Debug Transport Module, DMI CDC bridge, and Debug Module
- direct instruction-memory path
- AXI4-Lite data crossbar
- data memory slave
- UART transmit slave
- timer/watchdog slave
- health monitor slave

The CPU has separate instruction and data interfaces. Instruction fetch goes
directly to IMEM. Data accesses go through the AXI4-Lite crossbar.

## Why IMEM Bypasses the Crossbar

The CPU already has a dedicated instruction-fetch port. Keeping IMEM direct
simplifies the crossbar and avoids mixing fetch traffic with data/peripheral
traffic.

The crossbar still has an IMEM address slot, but it is connected to a null slave.
If software accidentally performs a data access to the instruction-memory region,
the null slave returns a decode error instead of pretending the write succeeded.

## AXI4-Lite Peripherals

The data crossbar currently exposes these slaves:

| Slave | Purpose |
| --- | --- |
| DMEM | Data memory with ECC telemetry |
| UART | Memory-mapped transmit byte and busy status |
| Timer/WDT | Timer interrupt, watchdog enable, watchdog kick, timeout |
| Health | ECC/TMR counters, live status, interrupt status, interrupt mask |
| Null IMEM slot | Decode-error response for invalid data access to IMEM |

The AXI4-Lite slaves are intentionally small. Each one accepts independent write
address and write data handshakes, returns simple OKAY responses for implemented
registers, and exposes a compact register map.

## Health Monitor

The health monitor is the bridge between Phase 1 hardening and Phase 2 system
visibility. It counts:

- IMEM/DMEM ECC correction events
- IMEM/DMEM ECC detection events
- TMR PC disagreements
- TMR FSM disagreements
- TMR register-file disagreements
- TMR instruction/control-path disagreements

It also provides:

- a live status register showing current fault wires
- latched interrupt status bits
- interrupt mask register
- write-one-to-clear interrupt status
- counter clear control

ECC telemetry comes directly from the memory slaves. TMR telemetry comes from the
CPU. The CPU does not need to sit in the middle of ECC reporting once memories
are SoC-level blocks.

## Watchdog Reset Decision

The watchdog reset only resets the CPU. It does not reset the JTAG/debug stack.

This is intentional: after a watchdog event, the debugger should still be able
to inspect the system and understand why the CPU reset. A full-chip reset would
make debug visibility worse.

## Interrupt Status

`timer_irq` and `health_irq` are produced by their peripherals and exported from
`soc_top`. They are not yet connected into the CPU as architectural interrupts.

That means the peripherals can be tested and observed now, while CPU interrupt
handling remains future work.

## Current Phase 2 Status

Implemented or partially implemented:

- AXI4-Lite memory slave
- AXI4-Lite UART slave
- AXI4-Lite timer/watchdog slave
- AXI4-Lite health monitor slave
- AXI4-Lite crossbar integration in `soc_top.sv`
- memory map constants in `rtl/package/axi4_lite_pkg.sv`

Still in progress:

- complete top-level SoC simulation signoff
- CPU interrupt connection
- DMA register block
- full firmware-style peripheral access test

The important design boundary is that Phase 2 is about system integration, not
adding more CPU features.
