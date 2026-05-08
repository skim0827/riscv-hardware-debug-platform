# RTL RISCV CORE — Code Explanation
This document explains every file in the simulator, line by line.  
Intended as a **personal study reference** not for GitHub readers.

---

## ALU 
To extend to RV32I
1. ALU Control (what ALU does) : used inside `alu.sv`
2. Decoder (how ALUControl is generated) : based on `opcode` + `funct3` + `funct7` 

```
Instruction → Decoder → ALUControl → ALU → Result
```

```
rs1 → SrcA
rs2 → SrcB
```

### ALUOp
The book (H&H) used `ALUOp`, which is a teaching abstraction. 
- `00` : Just ADD
- `01` : Just SUB
- `10` : Look deeper with `funct3` : R-type instructions

It is not part of the RISV-V ISA. So I changed `alu_decode.sv` to use flattened decode. 
```
opcode + funct3 + funct7 → ALUControl // no ALUOp signal at all using flattened decoder 
```

All loads (lb, lh, lw, lbu, lhu) do the same ALU operation:
```
address = rs1 + imm
→ ALU = ADD
```
So this entire `funct3` case is unnecessary.

| Opcode | Instruction Type | ALU Action    | Comment       |
|--------|------------------|---------------|---------------|
| 51     | R-type           | decode funct3 |               |
| 19     | I-type ALU       | decode funct3 |               |
| 3      | Load             | ADD           |               |
| 35     | Store            | ADD           |               |
| 99     | Branch           | SUB (basic)   |               |
| 23     | AUIPC            | ADD           | PC + upper_imm|
| 55     | LUI              | ADD / bypass  |  0 + upper_imm|
| 111    | JAL              | ADD           |       PC + imm|
| 103    | JALR             | ADD           |      rs1 + imm|

In S_DECODE for B-type, the FSM computes the branch target:
```
OldPC + ImmExt   → needs ALU_ADD
```

But `alu_decoder` sees `opcode=99`(branch) and outputs `ALU_SUB`. So the branch target stored in `alu_result_reg` is `OldPC - ImmExt`, wrong.

## Making Full RV32I 
### JALR 
- jump and link register 
- `PC = rs1 + SignExt(imm)`, `rd = PC + 4`
- I type 
- base register (`rs1`) and 12-bit immediate offset
- jump target = `rs1` + `immdediate`
- `JAL` has a large immediate (20-bit), no base register, target = `PC` + `immediate`
- `opcode` = `1101111`

```
S_DECODE  → ALU=OldPC+4  → latched into ALUOut
S_JALR    → ALU=rs1+imm  → PC = ALUResult (combinational)   rd pending
S_ALUWB   → ResultSrc=ALUOut = OldPC+4 → RegWrite → rd = OldPC+4 ✓
```
### U-Type 
- `immdediate` = 20-bits 
- U-Type represents a large constant (upper 20 bits)
- `ImmExt` = `{instr[31:12], 12'b0}`
- LUI (load upper immediate) : `rd` = `{upimm, 12’b0}`
- AUIPC (add upper immediate to PC) : `rd` = `{upimm, 12'b0} + PC`

### LUI
Approach 1 : Zero input on ALUSrcA mux (**simplest**)
```
ALUSrcA = 0 (constant) + ALUSrcB = ImmExt → ALUResult = ImmExt
```
Approach 2 : Bypass ALU entirely with a new ResultSrc
```
ResultSrc = ImmExt directly → rd = ImmExt
```
Approach 3 : Fold LUI into AUIPC with x0
`LUI rd, imm` is identical to `AUIPC rd, imm` if the PC were zero. Some compilers and ISA documents even describe LUI this way informally.
```
LUI  → ALUSrcA = rs1,  but force rs1 address = x0 → reads 0
AUIPC → ALUSrcA = OldPC
```

**Problem** 
```
LUI instruction format:
 31        12  11    7   6      0
 imm[31:12]    rd        opcode

bits [19:15] = imm[19:15]  ← part of the immediate, NOT an rs1 field
```

### All Branches
| funct3 | Branch | ALU op | Meaning of Zero                          |
|--------|--------|--------|------------------------------------------|
| 000    | BEQ    | SUB    | a == b                                   |
| 001    | BNE    | SUB    | a == b (but you invert it)               |
| 100    | BLT    | SLT    | result = 1 if a < b                      |
| 101    | BGE    | SLT    | result = 0 if a >= b                     |
| 110    | BLTU   | SLTU   | result = 1 if a < b (unsigned)           |
| 111    | BGEU   | SLTU   | result = 0 if a >= b                     |

- Pattern: invert = `funct3[0] ^ funct3[2]`
- `Zero` = `(result == 0)`
- `PCUpdate` : unconditional jumps (JAL, etc)

```verilog
logic branch_condition;
assign branch_condition = Zero ^ (funct3[0] ^ funct3[2]);
assign PCWrite = (branch_condition && Branch) || PCUpdate;
```

### Byte/half LD/ST 
```verilog 
always_ff @(posedge clk) begin
    if (IRWrite) instruction <= mem_rdata;  // latched in S_FETCH
end

assign funct3 = instruction[14:12];  // stable until next fetch
```
```
S_FETCH   : AdrSrc=0 → mem_funct3=3'b010 (word, forced)
                        funct3 is stale from previous instruction

S_MEMREAD : AdrSrc=1 → mem_funct3=funct3 (real, from latched IR)
                        funct3 is valid, same instruction still latched
```
## Control Signal 
### ALUSrcA 
- `2'b00` : PC 
- `2'b01` : OldPC
- `2'b10` : register (`rs1`)


### ALUSrcB 
- `2'b00` : `rs2` 
- `2'b01` : ImmExt 
- `2'b10` : 4 

### ResultSrc
- `2'b00` : from `ALUOut` register (stores ALU result for next cycle)
- `2'b01` : from data register (from Memory)
- `2'b10` : ALUResult (immediate output of ALU (combinational))

### AluSrc
- `1'b0` : from PC 
- `1'b1` : from result after ALU 