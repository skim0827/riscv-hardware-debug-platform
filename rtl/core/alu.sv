`timescale 1ns/1ps
module alu (
    input logic [31:0] srcA,
    input logic [31:0] srcB,
    input alu_control_t ALUControl,
    output logic [31:0] ALUResult,
    output logic Zero
);

import riscv_pkg::*;
always_comb begin 
    case (ALUControl)
        ALU_ADD : ALUResult = srcA + srcB;
        ALU_SUB : ALUResult = srcA - srcB;
        ALU_OR : ALUResult = srcA | srcB; 
        ALU_AND : ALUResult = srcA & srcB; // and 
        ALU_SLT : ALUResult = ($signed(srcA) < $signed(srcB)) ? 32'b1 : 32'b0; // slt
        default : ALUResult = srcA + srcB;
    endcase 
end
assign Zero = (ALUResult == 0);

endmodule 