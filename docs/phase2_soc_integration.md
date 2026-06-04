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

## Current Gaps

- CPU interrupt connection
- full top-level SoC simulation signoff
- DMA register block
- firmware-style peripheral tests
