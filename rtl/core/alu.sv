`timescale 1ns/1ps
module alu
import riscv_pkg::*;
(
    input logic [31:0] srcA,
    input logic [31:0] srcB,
    input alu_control_t ALUControl,
    output logic [31:0] ALUResult,
    output logic Zero
);

logic [4:0] shamt ; 
assign shamt = srcB[4:0];

always_comb begin
    case (ALUControl)
        ALU_ADD  : ALUResult = srcA + srcB;
        ALU_SUB  : ALUResult = srcA - srcB;
        ALU_OR   : ALUResult = srcA | srcB;
        ALU_AND  : ALUResult = srcA & srcB;
        ALU_XOR  : ALUResult = srcA ^ srcB;
        ALU_SLT  : ALUResult = ($signed(srcA) < $signed(srcB)) ? 32'b1 : 32'b0;
        ALU_SLTU : ALUResult = ($unsigned(srcA) < $unsigned(srcB)) ? 32'b1 : 32'b0;
        ALU_SLL  : ALUResult = srcA << shamt;
        ALU_SRL  : ALUResult = srcA >> shamt;
        ALU_SRA  : ALUResult = $signed(srcA) >>> shamt;
        // RVM (Harris Table B.5): funct7=0000001, opcode=0110011
        ALU_MUL    : ALUResult = (64'(signed'(srcA)) * 64'(signed'(srcB)))[31:0];
        ALU_MULH   : ALUResult = (64'(signed'(srcA)) * 64'(signed'(srcB)))[63:32];
        ALU_MULHSU : ALUResult = (64'(signed'(srcA)) * 64'(srcB))[63:32];
        ALU_MULHU  : ALUResult = (64'(srcA) * 64'(srcB))[63:32];
        ALU_DIV    : ALUResult = (srcB == 0) ? 32'hFFFFFFFF : 32'($signed(srcA) / $signed(srcB));
        ALU_DIVU   : ALUResult = (srcB == 0) ? 32'hFFFFFFFF : srcA / srcB;
        ALU_REM    : ALUResult = (srcB == 0) ? srcA : 32'($signed(srcA) % $signed(srcB));
        ALU_REMU   : ALUResult = (srcB == 0) ? srcA : srcA % srcB;
        default    : ALUResult = srcA + srcB;
    endcase
end
assign Zero = (ALUResult == 0);

endmodule 
