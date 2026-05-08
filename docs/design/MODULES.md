# Module Reference Documentation

Comprehensive reference guide for all SystemVerilog modules in the RISC-V hardware debug platform.

---

## Table of Contents

1. [CPU Core Modules](#cpu-core-modules)
2. [JTAG/Debug Modules](#jtagdebug-modules)
3. [Package Definitions](#package-definitions)
4. [Naming Conventions](#naming-conventions)

---

## CPU Core Modules

### cpu (rtl/core/cpu_top.sv)

**Purpose**: Top-level multi-cycle RISC-V processor core integrating instruction fetch, decode, execute, memory, and write-back stages, plus debug interface.

**Key Features**:
- Multi-cycle execution (one instruction completes before next begins)
- 32 × 32-bit general purpose registers
- Debug mode support (halt, resume, register inspection)
- Programme buffer execution
- RV32I instruction set

**Ports**:

| Signal | Dir | Width | Purpose |
|--------|-----|-------|---------|
| `clk` | IN | 1 | System clock |
| `rst_n` | IN | 1 | Active-low reset |
| **Hart (Debug) Interface** |
| `hart_halt_req` | IN | 1 | Request entry to debug mode |
| `hart_resume_req` | IN | 1 | Request resume from debug mode |
| `hart_reset_req` | IN | 1 | Request hart reset (multi-hart systems) |
| `hart_halted` | OUT | 1 | Indicates hart is halted and in debug mode |
| **Register File Access** |
| `hart_regfile_addr` | IN | 5 | GPR address to read/write (0–31) |
| `hart_regfile_wdata` | IN | 32 | Data to write to selected GPR |
| `hart_regfile_we` | IN | 1 | Register write enable (debugger driven) |
| `hart_regfile_rdata` | OUT | 32 | Data read from selected GPR |
| **Program Counter Access** |
| `hart_pc_wdata` | IN | 32 | PC value to load (debug mode) |
| `hart_pc_we` | IN | 1 | PC write enable (debugger driven) |
| `hart_pc_rdata` | OUT | 32 | Current PC value |
| **Programme Buffer Interface** |
| `progbuf_instr` | IN | 32 | Instruction to execute from programme buffer |
| `progbuf_exec` | IN | 1 | Execute instruction flag |
| `progbuf_done` | OUT | 1 | Instruction execution complete |
| `progbuf_exception` | OUT | 1 | Exception raised during execution |

**Multi-Cycle Execution**:

Each instruction advances sequentially through these stages, one stage per clock cycle (in most cases):

```
Stage 1 (IF):  Fetch instruction from memory at current PC
Stage 2 (ID):  Decode opcode, read source registers from regfile
Stage 3 (EX):  Execute ALU operation, compute branch target, calculate addresses
Stage 4 (MEM): Load/store memory operations
Stage 5 (WB):  Write results back to register file, update PC, move to next instruction
```

Only one instruction is active at any time. No pipelining means no instruction-level parallelism.

**Debug Mode Operation**:

When `hart_halt_req` is asserted:
1. CPU completes current instruction
2. Asserts `hart_halted=1`
3. Stops fetching new instructions
4. Allows external register/PC access via debug signals
5. When `hart_resume_req` asserted, resumes execution

---

### alu (rtl/core/alu.sv)

**Purpose**: Arithmetic and logic unit performing all computational operations.

**Ports**:

| Signal | Dir | Width | Purpose |
|--------|-----|-------|---------|
| `srcA` | IN | 32 | First operand |
| `srcB` | IN | 32 | Second operand |
| `ALUControl` | IN | enum | Operation selector (see riscv_pkg) |
| `ALUResult` | OUT | 32 | Computation result |
| `Zero` | OUT | 1 | '1' if ALUResult == 0, else '0' |

**Supported Operations** (ALUControl values):

| Operation | Code | Function |
|-----------|------|----------|
| ALU_ADD | 0 | `ALUResult = srcA + srcB` |
| ALU_SUB | 1 | `ALUResult = srcA - srcB` |
| ALU_AND | 2 | `ALUResult = srcA & srcB` (bitwise AND) |
| ALU_OR | 3 | `ALUResult = srcA \| srcB` (bitwise OR) |
| ALU_XOR | 4 | `ALUResult = srcA ^ srcB` (bitwise XOR) |
| ALU_SLL | 5 | `ALUResult = srcA << srcB[4:0]` (shift left logical) |
| ALU_SRL | 6 | `ALUResult = srcA >> srcB[4:0]` (shift right logical) |
| ALU_SRA | 7 | `ALUResult = srcA >>> srcB[4:0]` (shift right arithmetic) |
| ALU_SLT | 8 | `ALUResult = (srcA < srcB) ? 1 : 0` (signed less-than) |
| ALU_SLTU | 9 | `ALUResult = (srcA < srcB) ? 1 : 0` (unsigned less-than) |

**Timing**: Combinational (zero cycle latency)

---

### alu_decoder (rtl/core/alu_decoder.sv)

**Purpose**: Generates ALU control signals from instruction fields.

**Ports**:

| Signal | Dir | Width | Purpose |
|--------|-----|-------|---------|
| `opcode` | IN | 7 | Instruction opcode [6:0] |
| `funct3` | IN | 3 | Function code [14:12] |
| `funct7_bit5` | IN | 1 | Function code bit [31:25] (distinguishes add/sub, srl/sra) |
| `ALUControl` | OUT | enum | Decoded ALU operation |

**Logic**:

For R-type instructions, ALUControl is determined from `opcode`, `funct3`, and `funct7_bit5`:

```
R-type add (funct7[5]=0):  ALU_ADD
R-type sub (funct7[5]=1):  ALU_SUB
R-type and:                ALU_AND
R-type or:                 ALU_OR
... etc ...
```

---

### control (rtl/core/control.sv)

**Purpose**: Main instruction decode and pipeline control unit generating all control signals.

**Ports**:

| Signal | Dir | Width | Purpose |
|--------|-----|-------|---------|
| `clk` | IN | 1 | System clock |
| `rst_n` | IN | 1 | Active-low reset |
| `opcode` | IN | 7 | Instruction opcode [6:0] |
| `funct3` | IN | 3 | Instruction funct3 [14:12] |
| `funct7_5` | IN | 1 | Instruction bit [31:25] |
| `Zero` | IN | 1 | Zero flag from ALU (for branch outcome) |
| **Pipeline Control** |
| `PCWrite` | OUT | 1 | Update program counter |
| `RegWrite` | OUT | 1 | Write result to register file |
| `MemWrite` | OUT | 1 | Enable memory write |
| `IRWrite` | OUT | 1 | Load instruction register |
| **Multiplexer Selects** |
| `AdrSrc` | OUT | 1 | PC source: 0=PC+4, 1=Branch/Jump target |
| `ResultSrc` | OUT | 2 | Write-back source: 0=ALU, 1=Memory, 2=PC+4 |
| `ALUSrcA` | OUT | 2 | ALU srcA: 0=Rs1, 1=PC, 2=0 |
| `ALUSrcB` | OUT | 2 | ALU srcB: 0=Rs2, 1=Immediate, 2=4 |
| `ImmSrc` | OUT | 2 | Immediate format: 0=I-type, 1=S-type, 2=B-type, 3=J-type |
| **ALU Control** |
| `ALUControl` | OUT | enum | ALU operation selector |
| **Debug Interface** |
| `hart_halt_req` | IN | 1 | Request debug halt |
| `hart_resume_req` | IN | 1 | Request debug resume |
| `hart_halted` | OUT | 1 | Debug mode active flag |

**Control Logic**:

Implements a finite state machine identifying instruction type and setting appropriate control signals. Handles branch prediction and pipeline flushing on control flow changes.

---

### instr_decoder (rtl/core/instr_decoder.sv)

**Purpose**: Extracts and decodes instruction fields.

**Ports**:

| Signal | Dir | Width | Purpose |
|--------|-----|-------|---------|
| `instr` | IN | 32 | 32-bit instruction word |
| `opcode` | OUT | 7 | Bits [6:0] – operation code |
| `rd` | OUT | 5 | Bits [11:7] – destination register |
| `funct3` | OUT | 3 | Bits [14:12] – function code |
| `rs1` | OUT | 5 | Bits [19:15] – first source register |
| `rs2` | OUT | 5 | Bits [24:20] – second source register |
| `funct7` | OUT | 7 | Bits [31:25] – function code extension |

**Usage**: Breaks down instruction into constituent fields for use by control and ALU decoder modules.

---

### regfile (rtl/core/regfile.sv)

**Purpose**: 32 × 32-bit register file with dual read and single write ports, plus debug access.

**Ports**:

| Signal | Dir | Width | Purpose |
|--------|-----|-------|---------|
| `clk` | IN | 1 | System clock |
| `A1` | IN | 5 | Read address 1 (instruction Rs1) |
| `A2` | IN | 5 | Read address 2 (instruction Rs2) |
| `A3` | IN | 5 | Write address (instruction Rd) |
| `WD3` | IN | 32 | Write data |
| `WE3` | IN | 1 | Write enable |
| `RD1` | OUT | 32 | Data from A1 |
| `RD2` | OUT | 32 | Data from A2 |
| **Debug Interface** |
| `dbg_addr` | IN | 5 | Debug read address (register number 0–31) |
| `dbg_rdata` | OUT | 32 | Data from debug read |

**Behaviour**:

- Reads are combinational (no pipeline latency)
- Writes occur on rising clock edge when `WE3=1`
- Register x0 is always zero (write attempts ignored)
- Debug reads are separate from main datapath

**Special Notes**:

- On reset, all registers initialise to zero
- No forwarding logic (pipeline hazards managed by control unit)

---

### memory (rtl/core/memory.sv)

**Purpose**: Unified instruction and data memory for simulation.

**Ports**:

| Signal | Dir | Width | Purpose |
|--------|-----|-------|---------|
| `clk` | IN | 1 | System clock |
| `A` | IN | 32 | Address (word-aligned) |
| `WD` | IN | 32 | Write data |
| `WE` | IN | 1 | Write enable |
| `RD` | OUT | 32 | Read data (combinational) |

**Capacity**: 2K × 32-bit words (8 KB total)

**Access Pattern**:

- **Reads** are combinational
- **Writes** occur on rising edge when `WE=1`
- Unaligned accesses are not supported (would cause errors)

**Initialisation**: Loads from optional `.hex` file on reset (for pre-loading programmes)

---

### program_counter (rtl/core/program_counter.sv)

**Purpose**: Program counter register management with debug write capability.

**Ports**:

| Signal | Dir | Width | Purpose |
|--------|-----|-------|---------|
| `clk` | IN | 1 | System clock |
| `rst_n` | IN | 1 | Active-low reset |
| `PCNext` | IN | 32 | Next PC value (from mux based on branch outcome) |
| `PCWrite` | IN | 1 | Update enable |
| `PC` | OUT | 32 | Current PC (instruction address) |
| **Debug Interface** |
| `dbg_pc_wdata` | IN | 32 | Debug write value (from debugger) |
| `dbg_pc_we` | IN | 1 | Debug write enable |
| `dbg_pc_rdata` | OUT | 32 | Debug read value (current PC) |

**Reset Behaviour**: PC initialises to 0x0000_0000

**Debug Mode**: When `dbg_pc_we=1`, PC is loaded from `dbg_pc_wdata` immediately on next clock (overrides `PCNext`)

---

### signext (rtl/core/signext.sv)

**Purpose**: Sign-extends immediate values from instruction encoding.

**Ports**:

| Signal | Dir | Width | Purpose |
|--------|-----|-------|---------|
| `instr` | IN | 32 | 32-bit instruction word |
| `ImmSrc` | IN | 2 | Format selector: 0=I-type, 1=S-type, 2=B-type, 3=J/U-type |
| `ImmExt` | OUT | 32 | Sign-extended immediate |

**Immediate Formats**:

```
I-type (load, addi, etc):     [31:20]           (12-bit signed)
S-type (store):               [31:25] [11:7]    (12-bit signed)
B-type (branch):              [31:25] [11:8] 0  (13-bit signed, always even)
J-type (jal):                 [31:20] [10:1] 0  (21-bit signed, always even)
U-type (lui, auipc):          [31:12] 0...0     (20-bit left-shifted)
```

---

## JTAG/Debug Modules

### tap_fsm (rtl/jtag/tap_fsm.sv)

**Purpose**: IEEE 1149.1 JTAG Test Access Port (TAP) controller state machine.

**Ports**:

| Signal | Dir | Width | Purpose |
|--------|-----|-------|---------|
| `tck` | IN | 1 | Test clock (debugger clock) |
| `tms` | IN | 1 | Test mode select (state control) |
| `tdi` | IN | 1 | Test data in (debugger → tap) |
| `tdo` | OUT | 1 | Test data out (tap → debugger) |
| `trst_n` | IN | 1 | TAP reset (async, active-low) |
| **Tap State Signals** |
| `tap_state` | OUT | 4 | Current TAP state (for observation) |
| `capture_ir` | OUT | 1 | Strobe for capturing IR |
| `shift_ir` | OUT | 1 | Enable IR shift operation |
| `update_ir` | OUT | 1 | Strobe for updating IR register |
| `capture_dr` | OUT | 1 | Strobe for capturing DR |
| `shift_dr` | OUT | 1 | Enable DR shift operation |
| `update_dr` | OUT | 1 | Strobe for updating DR register |

**TAP States** (IEEE 1149.1):

- **IDLE**: Default, reset state
- **CAPTURE**: Load shift register input mux
- **SHIFT**: Shift data through register
- **EXIT1**: Prepare to update or change mode
- **UPDATE**: Load shift register into target
- Other states (SETUP, HOLD, etc.) as per IEEE standard

**Functionality**:

- Transitions between states based on `tms` input on each rising `tck` edge
- Generates appropriate strobe signals to coordinate IR/DR operations
- On `trst_n` (async reset), returns to IDLE state

---

### dtm_top (rtl/dtm/dtm_top.sv)

**Purpose**: Debug Transport Module – converts JTAG IR/DR sequences into DMI (Debug Module Interface) transactions.

**Ports**:

| Signal | Dir | Width | Purpose |
|--------|-----|-------|---------|
| **JTAG Signals** |
| `tck` | IN | 1 | Test clock |
| `tdi` | IN | 1 | Test data in |
| `tdo` | OUT | 1 | Test data out |
| `capture_ir` | IN | 1 | Strobe when IR should be loaded |
| `shift_ir` | IN | 1 | Shift mode for IR |
| `update_ir` | IN | 1 | Strobe when IR should be committed |
| `capture_dr` | IN | 1 | Strobe when DR should be loaded |
| `shift_dr` | IN | 1 | Shift mode for DR |
| `update_dr` | IN | 1 | Strobe when DR should be committed |
| **DMI Interface** |
| `dmi_addr` | OUT | 7 | DMI register address |
| `dmi_wdata` | OUT | 32 | DMI write data payload |
| `dmi_we` | OUT | 1 | DMI write enable |
| `dmi_re` | OUT | 1 | DMI read enable |
| `dmi_rdata` | IN | 32 | DMI read data response |

**Operation**:

1. Debugger shifts 5-bit instruction into IR (IDCODE, DEBUG, BYPASS)
2. If DEBUG selected, debugger shifts 41-bit transaction into DEBUG DR:
   - Bits [40:34] = destination register address
   - Bits [33:2] = 32-bit data payload
   - Bits [1:0] = operation (00=NOP, 01=READ, 10=WRITE, 11=reserved)
3. On UPDATE strobe, DTM converts DMI format and drives `dmi_addr`, `dmi_wdata`, `dmi_we`/`dmi_re`
4. Response data from Debug Module is captured into DR for next shift operation

**Example Transaction**:

```
Shift in: IR=0x02 (DEBUG selected)
Shift in DR: {addr=0x10, data=0x80000001, op=WRITE}
On update_dr: dmi_we=1, dmi_addr=7'h10, dmi_wdata=32'h80000001
Debug Module receives halt request (dmcontrol.haltreq bit)
```

---

### debug_module (rtl/debug/debug_module.sv)

**Purpose**: RISC-V Debug Module implementing register operations and debug control.

**Ports**:

| Signal | Dir | Width | Purpose |
|--------|-----|-------|---------|
| `clk` | IN | 1 | System clock |
| `rst_n` | IN | 1 | Active-low reset |
| **DMI Interface** |
| `dmi_addr` | IN | 7 | Register address |
| `dmi_wdata` | IN | 32 | Write data |
| `dmi_we` | IN | 1 | Write enable |
| `dmi_re` | IN | 1 | Read enable |
| `dmi_rdata` | OUT | 32 | Read data (registered) |
| **Hart Control** |
| `hart_halt_req` | OUT | 1 | Request hart to enter debug mode |
| `hart_resume_req` | OUT | 1 | Request hart to resume |
| `hart_halted` | IN | 1 | Hart status (from CPU) |
| **Register File Access** |
| `hart_regfile_addr` | OUT | 5 | GPR address to access |
| `hart_regfile_wdata` | OUT | 32 | Data to write to GPR |
| `hart_regfile_we` | OUT | 1 | GPR write enable |
| `hart_regfile_rdata` | IN | 32 | GPR read data |
| **PC Access** |
| `hart_pc_wdata` | OUT | 32 | PC value to load |
| `hart_pc_we` | OUT | 1 | PC write enable |
| `hart_pc_rdata` | IN | 32 | Current PC |
| **Programme Buffer** |
| `progbuf_instr` | OUT | 32 | Instruction to execute |
| `progbuf_exec` | OUT | 1 | Execute instruction |
| `progbuf_done` | IN | 1 | Execution complete |
| `progbuf_exception` | IN | 1 | Exception during execution |

**Key Registers** (RISC-V Debug Spec v0.13.2):

| Address | Register | Bits | Purpose |
|---------|----------|------|---------|
| 0x10 | DMCONTROL | [0] haltreq | Request hart halt |
| | | [1] resumereq | Request hart resume |
| | | [16] ndmreset | Non-debug module reset |
| | | [17] dmactivebit | Debug module active |
| 0x11 | DMSTATUS | [0] anyhalted | Any hart halted |
| | | [1] allhalted | All harts halted |
| | | [8] anyrunning | Any hart running |
| | | [9] allrunning | All harts running |
| | | [17:16] version | SBA protocol version |
| 0x04–0x0F | DATA0–DATA11 | [31:0] value | Scratch data for abstract commands |
| 0x17 | COMMAND | [31:24] priority | Reserved |
| | | [23:16] type | Command type (AccessRegister, etc.) |
| | | [15:12] aarpostincrement | Auto-increment address after operation |
| | | [11:0] address | Target register address |
| 0x20–0x2F | PROGBUF0–PROGBUF15 | [31:0] instr | Programme buffer instructions |

**Behaviour**:

- Responds to DMI read/write operations on clock edges
- Asserts `hart_halt_req` when debugger requests halt via DMCONTROL
- Manages multi-step debug sequences (halt → inspect → step → resume)
- Provides access to CPU registers and programme buffer

---

## Package Definitions

### riscv_pkg (rtl/package/riscv_pkg.sv)

**Purpose**: RISC-V ISA constants and type definitions.

**Key Definitions**:

```systemverilog
// Instruction Opcodes (7-bit)
parameter [6:0] OPCODE_LOAD      = 7'b00_00011;
parameter [6:0] OPCODE_STORE     = 7'b01_00011;
parameter [6:0] OPCODE_BRANCH    = 7'b11_00011;
parameter [6:0] OPCODE_JALR      = 7'b11_00111;
parameter [6:0] OPCODE_JAL       = 7'b11_01111;
parameter [6:0] OPCODE_OP_IMM    = 7'b00_10011;
parameter [6:0] OPCODE_OP        = 7'b01_10011;
parameter [6:0] OPCODE_AUIPC     = 7'b00_10111;
parameter [6:0] OPCODE_LUI       = 7'b01_10111;

// ALU Control Enum
enum logic [3:0] {
    ALU_ADD = 4'b0000,
    ALU_SUB = 4'b0001,
    ALU_AND = 4'b0010,
    ALU_OR  = 4'b0011,
    ALU_XOR = 4'b0100,
    ALU_SLL = 4'b0101,
    ALU_SRL = 4'b0110,
    ALU_SRA = 4'b0111,
    ALU_SLT = 4'b1000,
    ALU_SLTU = 4'b1001
} alu_control_t;
```

---

### dmi_pkg (rtl/package/dmi_pkg.sv)

**Purpose**: Debug Module Interface constants and register definitions.

**Key Definitions**:

```systemverilog
// DMI Operation Codes (2-bit)
parameter [1:0] DMI_OP_NOP   = 2'b00;
parameter [1:0] DMI_OP_READ  = 2'b01;
parameter [1:0] DMI_OP_WRITE = 2'b10;

// Register Addresses (RISC-V Debug Spec)
parameter [6:0] DMI_DMCONTROL   = 7'h10;
parameter [6:0] DMI_DMSTATUS    = 7'h11;
parameter [6:0] DMI_HARTINFO    = 7'h12;
parameter [6:0] DMI_ABSTRACTCS  = 7'h16;
parameter [6:0] DMI_COMMAND     = 7'h17;
parameter [6:0] DMI_DATA0       = 7'h04;
parameter [6:0] DMI_DATA1       = 7'h05;
// ... DATA2–DATA11 ...
parameter [6:0] DMI_PROGBUF0    = 7'h20;
parameter [6:0] DMI_PROGBUF1    = 7'h21;
// ... PROGBUF2–PROGBUF15 ...
```

---

## Naming Conventions

### Signal Naming

When writing new modules, follow these conventions:

**General Rules**:

- **Inputs**: Lower case, no prefix (e.g., `addr`, `data`, `enable`)
- **Outputs**: Lower case with `_o` suffix (e.g., `result_o`, `valid_o`)
- **Clocks**: `clk`, `clk_en`, `clk_div2`
- **Resets**: `rst_n` (active-low), `rst` (active-high)
- **Active-low signals**: Append `_n` suffix (e.g., `write_n`, `chip_enable_n`)

**Module Signals**:

- **Internal registers**: Append `_r` (e.g., `counter_r`, `state_r`)
- **Next-cycle values**: Append `_next` (e.g., `counter_next`, `state_next`)
- **Debug signals**: Prefix with `dbg_` (e.g., `dbg_addr`, `dbg_halt`)
- **Status/flag outputs**: Append `_flag` or use adjective (e.g., `valid`, `empty`, `full`)

**Examples**:

```systemverilog
// Good naming
input logic [31:0] data,
input logic        enable,
output logic [31:0] result_o,
output logic       valid_o,

logic [31:0] data_r;        // Register holding data
logic [31:0] data_next;     // Next value for data_r
logic        dbg_halt_req;  // Debug halt request
logic        empty_flag;    // FIFO is empty
```

### Port Ordering Convention

For consistency, order module ports as:

1. **Clock and Reset**: `clk`, `rst_n`
2. **Main Data Inputs**: Command, address, data (as applicable)
3. **Main Data Outputs**: Result, status, acknowledgement
4. **Side Channels**: Debug signals, test signals, etc.

**Example**:

```systemverilog
module somemodule(
    input logic clk,
    input logic rst_n,
    
    input logic [4:0] addr,
    input logic [31:0] wdata,
    input logic we,
    
    output logic [31:0] rdata,
    output logic valid,
    
    input logic debug_halt_req,
    output logic debug_halted
);
```

---

## Related Documentation

- See **[TESTING.md](TESTING.md)** for how to test individual modules
- See **[ARCHITECTURE.md](ARCHITECTURE.md)** for system-level diagrams
- See **[README.md](../README.md)** for build and usage instructions

---

**Document Version**: 1.0  
**Last Updated**: April 2026  
**Status**: Complete for Phase 1/2
