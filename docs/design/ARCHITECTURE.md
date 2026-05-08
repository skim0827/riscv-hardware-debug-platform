# RISC-V Multi-cycle Processor Architecture

## With JTAG Debug Support (RISC-V v0.13.2 Compliant)

### Overview

This document describes the architecture of a 32-bit RISC-V processor with external debugging capabilities via JTAG interface, implementing RISC-V Debug Specification v0.13.2. The design emphasises clarity and demonstrating processor design principles whilst maintaining compliance with industry standards.

---

## System-Level Architecture

### Complete System Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                     External Debugger (GDB/OpenOCD)              │
│                          via JTAG Port                           │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │   JTAG TAP Ctrl │ (IEEE 1149.1)
                    │   (tap_fsm.sv)  │
                    └────────┬────────┘
                             │
            ┌────────────────▼─────────────────┐
            │ Debug Transport Module (DTM)     │
            │   Converts TAP → DMI protocol    │
            │   (dtm_top.sv)                   │
            └────────────────┬─────────────────┘
                             │
                     (DMI Bus - 41-bit)
                             │
         ┌───────────────────▼────────────────────┐
         │    Debug Module (debug_module.sv)      │
         │  ┌─────────────────────────────────┐   │
         │  │ • DMSTATUS / DMCONTROL regs     │   │
         │  │ • Abstract Command Handler      │   │
         │  │ • Data Registers (DATA0-11)     │   │
         │  │ • Programme Buffer (PROGBUF)    │   │
         │  └─────────────────────────────────┘   │
         └───────────────────┬────────────────────┘
                             │
         ┌───────────────────▼────────────────────┐
         │   Hart Debug Interface Signals         │
         │  • dbg_halt, dbg_step                  │
         │  • dbg_reg_we, dbg_reg_wdata           │
         │  • dbg_pc_we, dbg_pc_wdata             │
         └───────────────────┬────────────────────┘
                             │
         ┌───────────────────▼──────────────────────┐
         │        RISC-V CPU Core (cpu_top.sv)      │
         │  ┌──────────────────────────────────┐    │
         │  │  Multi-Cycle Execution           │    │
         │  │  (One instruction at a time)     │    │
         │  │  IF → ID → EX → MEM → WB         │    │
         │  │                                  │    │
         │  │  • 32 × 32-bit Register File     │    │
         │  │  • ALU (logic & arithmetic)      │    │
         │  │  • PC and DPC (debug PC)         │    │
         │  │  • Main memory interface         │    │
         │  └──────────────────────────────────┘    │
         └──────────────────────────────────────────┘
```

---

## Component Details

### 1. JTAG Interface (IEEE 1149.1)

**Files**: `rtl/jtag/tap_fsm.sv`

The JTAG Test Access Port provides the physical debugging interface.

#### Signals

| Signal | Direction | Width | Purpose |
|--------|-----------|-------|---------|
| `tck` | IN | 1 | Test Clock – clocks the TAP state machine |
| `tms` | IN | 1 | Test Mode Select – controls TAP state transitions |
| `tdi` | IN | 1 | Test Data In – serial data from debugger |
| `tdo` | OUT | 1 | Test Data Out – serial data to debugger |
| `trst_n` | IN | 1 | Reset (async) – initialises TAP to IDLE state |

#### TAP State Machine

The TAP controller implements a 16-state finite state machine per IEEE 1149.1:

![tap controller diagram](images/tap-controller-fsm.png)
#### Supported Instructions

| Instruction | IR Code | Purpose |
|------------|---------|---------|
| IDCODE | `0x01` | Read 32-bit chip identification code |
| DEBUG | `0x02` | Access Debug Module (via DMI) |
| BYPASS | `0x1F` | 1-bit shift register for test bypass |

---

### 2. Debug Transport Module (DTM)

**Files**: `rtl/dtm/dtm_top.sv`

Converts JTAG IR/DR sequences into DMI (Debug Module Interface) transactions.

#### Block Diagram

```
    ┌──────────────────────┐
    │   JTAG TAP Signals   │
    │  tck, tdi, tdo, etc  │
    └──────────┬───────────┘
               │
        ┌──────▼──────┐
        │     IR      │ (5-bit instruction register)
        │   Register  │ Holds current JTAG instruction
        └──────┬──────┘
               │
    ┌──────────┴──────────┐
    │                     │
    ▼                     ▼
┌────────────┐       ┌──────────┐
│ IDCODE DR  │       │ DEBUG DR │ (41-bit)
│  (32-bit)  │       │ (DMI ops)│
└────────────┘       └──────┬───┘
                            │
                     ┌──────▼──────┐
                     │  DMI Engine │
                     └──────┬──────┘
                            │
                     ┌──────▼──────────┐
                     │  DMI Bus (41b)  │
                     │ to Debug Module │
                     └─────────────────┘
```

#### DMI Transaction Format (41-bit)

```
Bit Layout:  [40:34] [33:2] [1:0]
             ┌──────┬──────┬────┐
             │ ADDR │ DATA │ OP │
             └──────┴──────┴────┘
              7 bits 32 bits 2 bits
```

| Field | Bits | Purpose |
|-------|------|---------|
| Operation | [1:0] | `00` = NOP, `01` = READ, `10` = WRITE, `11` = Reserved |
| Address | [8:2] | 7-bit debug register address |
| Data | [40:9] | 32-bit payload (write data OR read response) |

#### Example: Writing to DMCONTROL

```
Transaction: halt the processor by setting haltreq

DTM Operation:
1. Shift WRITE (10) and address 0x10 (dmcontrol) into DEBUG DR
2. Shift data 0x8000_0001 (haltreq=1, ndmreset=0)
3. Drive update_dr to commit transaction

DMI Bus sends: {addr=0x10, data=0x8000_0001, op=WRITE}
Debug Module receives and sets haltreq signal
CPU immediately recognises halt request
```

---

### 3. Debug Module

**Files**: `rtl/debug/debug_module.sv`

Implements RISC-V Debug Specification v0.13.2 registers and command handling.

#### Register Map

| Address | Register | Purpose |
|---------|----------|---------|
| 0x10 | DMCONTROL | Debug control and configuration |
| 0x11 | DMSTATUS | Debug status and hart state |
| 0x04–0x0F | DATA0–DATA11 | 12 data registers for command operations |
| 0x17 | COMMAND | Abstract command execution |
| 0x20–0x2F | PROGBUF0–PROGBUF15 | 16 programme buffer entries |

#### Control Signals to CPU

| Signal | Direction | Width | Purpose |
|--------|-----------|-------|---------|
| `dbg_halt` | OUT | 1 | Assert to request debug mode |
| `dbg_step` | OUT | 1 | Single-step mode enable |
| `dbg_reg_we` | OUT | 1 | Register write enable |
| `dbg_reg_addr` | OUT | 5 | Register address to access |
| `dbg_reg_wdata` | OUT | 32 | Data to write to register |
| `dbg_pc_we` | OUT | 1 | PC write enable |
| `dbg_pc_wdata` | OUT | 32 | PC value to write |
| `dbg_halted` | IN | 1 | Confirms hart is halted |
| `dbg_running` | IN | 1 | Confirms hart is executing |

---

### 4. CPU Core

**Files**: `rtl/core/cpu_top.sv` and sub-modules




#### Core Submodules

| Module | File | Function |
|--------|------|----------|
| **ALU** | `alu.sv` | Arithmetic and logic operations |
| **ALU Decoder** | `alu_decoder.sv` | ALU control signal generation |
| **Control** | `control.sv` | Main instruction decode & control FSM |
| **Instruction Decoder** | `instr_decoder.sv` | Opcode parsing and validation |
| **Register File** | `regfile.sv` | 32 × 32-bit general purpose registers |
| **Sign Extension** | `signext.sv` | Immediate value sign-extension |
| **Main FSM** | `main_fsm.sv` | Multi-cycle state machine controlling execution stages |
| **Program Counter** | `program_counter.sv` | PC management and updates |
| **Memory** | `memory.sv` | Instruction and data memory |

#### Instruction Set Support

**Implemented (RV32I Base)**:

- **R-type**: add, sub, and, or, xor, slt, sltu
- **I-type**: addi, andi, ori, xori, slti, sltiu, lw, addi (shifts via I-type), jalr
- **S-type**: sw, sh, sb
- **B-type**: beq, bne, blt, bge, bltu, bgeu
- **J-type**: jal
- **U-type**: lui, auipc

**Total**: 32 instructions

**Not Yet Implemented**:
- M-type (mul, div, rem)
- Full CSR support 
- Floating-point 

---

## Memory Architecture

```
┌─────────────────────────────────────────────┐
│          Physical Address Space             │
├─────────────────────────────────────────────┤
│ 0x0000_0000 – 0x7FFF_FFFF │ Instruction     │
│                           │ Memory (2 GB)   │
├─────────────────────────────────────────────┤
│ 0x8000_0000 – 0xFFFF_FFFF │ Data Memory     │
│                           │ (2 GB)          │
└─────────────────────────────────────────────┘
```

### Simplified Memory Model

- **Single-cycle access** for both load and store operations
- **32-bit memory bus** aligned to word boundaries
- **No caching** (intended for small embedded systems)
- **Unified instruction/data memory** in simulation


---

## Key Design Decisions

### Why Multi-cycle?

- **Clarity**: Straightforward state machine logic, easy to follow execution flow
- **Simplicity**: No pipeline hazards (structural, data, control) to manage
- **Realism**: Demonstrates fundamental processor design concepts
- **Achievable CPI**: Typically 3-7 cycles per instruction depending on instruction type
- **Educational value**: Clear separation of concerns between fetch, decode, execute, memory, and write-back phases

### Why RV32I (not RV32IM)?

- **Complete base**: RV32I is sufficient for most algorithms
- **Multiply/divide**: Added in Phase 2 as a modular extension
- **Scope**: Keeps core design focused
- **Verification**: Easier to achieve comprehensive test coverage

### Why JTAG + DMI?

- **Industry standard**: JTAG is ubiquitous in silicon debugging
- **RISC-V compliant**: DMI is mandated by RISC-V Debug Spec
- **Tool support**: OpenOCD, GDB, commercial tools all support JTAG
- **Extensibility**: Can add other debug transports (SWD, etc.) later

---

## Performance Characteristics

### Target Specifications

| Metric | Target |
|--------|--------|
| Clock frequency | 100+ MHz |
| CPI (cycles per instruction) | 3–7 (depending on instruction type) |
| Area (LUTs, estimated) | 4–5K |
| Power (typical, estimated) | ~200 mW |
| Memory latency | 1 cycle |


**Key Characteristics**:

- **No pipelining**: Each instruction completes before the next begins
- **Predictable CPI**: Roughly 3-5 cycles for ALU operations, 4-7 for memory operations
- **No hazards**: No data, structural, or control hazards due to lack of pipelining
- **Simple control**: One instruction active at a time makes state machine straightforward

---

## Current Implementation Status

✅ = Completed  
🔄 = In Progress  
📋 = Planned

- ✅ TAP FSM (JTAG state machine)
- ✅ JTAG IR/DR register implementation
- ✅ DMI protocol engine
- ✅ Basic 32-register CPU core
- ✅ 5-stage pipeline with synchronous operation
- ✅ RV32I instruction set (32 base instructions)
- ✅ Simple memory sub-system
- 🔄 Full Debug Module register set
- 🔄 Abstract command execution
- 📋 Programme buffer support
- 📋 M-extension (multiply/divide)
- 📋 Full CSR support

---

## Related Documentation

- See **[MODULES.md](MODULES.md)** for detailed module signal descriptions
- See **[DEBUG_PROTOCOL.md](../../DEBUG_PROTOCOL.md)** for RISC-V Debug Spec details
- See **[TESTING.md](TESTING.md)** for simulation and verification methodology

---

