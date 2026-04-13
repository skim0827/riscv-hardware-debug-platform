# RISC-V Multicycle Processor Architecture
## With JTAG Debug Support (RISC-V v0.13.2 Compliant)

### Overview
This document describes the architecture of a 32-bit RISC-V processor with 
external debugging capabilities via JTAG interface, implementing RISC-V Debug 
Specification v0.13.2.

### System Architecture Diagram
```
Debugger (gdb via OpenOCD)
        ↓
    JTAG/DTM
        ↓
    DMI Bus (Debug Module Interface)
        ↓
┌─────────────────────────────────┐
│    Debug Module (this design)    │
├─────────────────────────────────┤
│ • Status/Control (DMSTATUS, etc)│
│ • Abstract Commands Handler     │
│ • Data Register Storage         │
│ • Program Buffer                │
└─────────────────────────────────┘
        ↓
   Hart Interface
        ↓
┌─────────────────────────────────┐
│    RISC-V CPU Core              │
│ • Register File (GPRs)          │
│ • PC/DPC                        │
│ • Program Buffer Execution      │
└─────────────────────────────────┘
```
### Core Components

#### 1. JTAG Interface (jtag_top.sv, tap_fsm.sv)
IEEE 1149.1 compliant JTAG TAP controller.

**Signals:**
- TCK: Test Clock (from debugger)
- TMS: Test Mode Select (from debugger)
- TDI: Test Data In (from debugger)
- TDO: Test Data Out (to debugger)

**Supported Instructions:**
- IDCODE (0x01) - Chip identification
- DEBUG (0x02) - Access debug module
- BYPASS (0x1f) - Test bypass

#### 2. DTM - Debug Transport Module (dtm_top.sv)
Converts JTAG sequences into DMI protocol.

**Implements:**
- IR (Instruction Register) - Selects active DR
- DR (Data Registers) - IDCODE, DEBUG data, BYPASS
- DMI transaction protocol (41-bit)

#### 3. Debug Module (debug_module.sv → debug_module_v2.sv)
Implements RISC-V Debug specification registers and command execution.

**Phase 2 Implements:**
- dmstatus (0x11) - Status register
- dmcontrol (0x10) - Control register
- command (0x17) - Abstract command execution
- data0-11 (0x04-0x0f) - Data registers
- progbuf0-15 (0x20-0x2f) - Program buffer

#### 4. CPU Hart (cpu_top.sv and submodules)
5-stage multicycle RISC-V RV32I processor.

**Stages:**
1. IF - Instruction Fetch
2. ID - Instruction Decode  
3. EX - Execute
4. MEM - Memory Access
5. WB - Write-back

**Debug Interface Signals:**
- dbg_halt - Request debug mode entry
- dbg_step - Single-step mode
- dbg_reg_we - Register write enable
- dbg_reg_addr - Register address
- dbg_reg_wdata - Register write data
- dbg_pc_we - Program counter write enable
- dbg_pc_wdata - Program counter value

### Instruction Set Support

**Implemented (RV32I Base):**
- R-type: add, sub, and, or, xor, slt, sltu
- I-type: addi, andi, ori, xori, slti, sltiu
- S-type: sw, sh, sb
- B-type: beq, bne, blt, bge, bltu, bgeu
- J-type: jal, jalr
- U-type: lui, auipc
- **Total: 32 instructions**

**Not Yet Implemented:**
- M-type: mul, div (Tier 2)
- CSRs: Full CSR support (Tier 2)

### Memory Map
### Debug Protocol Overview

#### DMI (Debug Module Interface) Transaction Format
41-bit master-slave protocol:
- **Bits [40:9]** - 32-bit data payload
- **Bits [8:2]** - 7-bit register address  
- **Bits [1:0]** - 2-bit operation code

Operation codes:
- 00 = NOP
- 01 = READ
- 10 = WRITE
- 11 = Reserved

#### Example: Halt a Hart
1. Debugger sends JTAG sequence
2. DTM converts to DMI transaction: write 0x8000_0001 to address 0x10
3. Debug Module receives haltreq=1 in dmcontrol
4. CPU sees halt request and enters Debug Mode
5. Debug Module sets anyhalted=1 in dmstatus
6. Debugger reads dmstatus, confirms hart halted

### Key Design Decisions

**Why 5-Stage Multicycle?**
- Clear educational value
- Realistic complexity
- Shows understanding of pipelines
- CPI ~1.3-1.5 achievable

**Why RV32I (not RV32IM)?**
- Complete base instruction set
- Multiply/divide is Phase 2 extension
- Sufficient for demonstrating processor design

**Why JTAG?**
- Standard industry protocol
- Wide tool support
- RISC-V spec aligned
- Educational value

### Performance Targets

- **Frequency:** 100+ MHz
- **Area:** 4-5K LUTs
- **Power:** ~200mW (estimated)
- **CPI:** ~1.3-1.5

### Current Status (End of Phase 2)

- [x] TAP FSM implemented
- [x] JTAG IR/DR registers  
- [x] DMI protocol
- [x] Basic debug module
- [ ] Full spec compliance (Phase 2 goal)
- [ ] Abstract commands (Phase 2 goal)
- [ ] Program buffer (Phase 2/3 goal)