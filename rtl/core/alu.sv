`timescale 1ns/1ps
module alu (
    input logic [31:0] srcA,
    input logic [31:0] srcB,
    input alu_control_t ALUControl,
    output logic [31:0] ALUResult,
    output logic Zero
);

import riscv_pkg::*;
logic [4:0] shamt ; 
assign shamt = srcB[4:0];

always_comb begin 
    case (ALUControl)
        ALU_ADD : ALUResult = srcA + srcB;
        ALU_SUB : ALUResult = srcA - srcB;
        ALU_OR : ALUResult = srcA | srcB; 
        ALU_AND : ALUResult = srcA & srcB;
        ALU_XOR : ALUResult = srcA ^ srcB;
        ALU_SLT : ALUResult = ($signed(srcA) < $signed(srcB)) ? 32'b1 : 32'b0; // Set Less Than (signed)
        ALU_SLTU : ALUResult = ($unsigned(srcA) < $unsigned(srcB)) ? 32'b1 : 32'b0; // Set Less Than Unsigned
        ALU_SLL : ALUResult = srcA << shamt; // Shift Left Logical
        ALU_SRL : ALUResult = srcA >> shamt; // Shift Right Logical
        ALU_SRA : ALUResult = $signed(srcA) >>> shamt; // Shift Right Arithmetic        
        default : ALUResult = srcA + srcB;
    endcase 
end
assign Zero = (ALUResult == 0);

endmodule 