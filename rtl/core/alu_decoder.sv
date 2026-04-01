`timescale 1ns/1ps
module alu_decoder (
    input logic op5, 
    input logic [2:0] funct3, 
    input logic funct7_5,
    input logic [1:0] ALUOp,

    output alu_control_t ALUControl 
);

import riscv_pkg::*;
always_comb begin
    // page 409
    case (ALUOp) 
        2'b00 : begin
            ALUControl = ALU_ADD; // lw , sw

        end 
        2'b01 : begin
            ALUControl = ALU_SUB; // beq 

        end 
        2'b10 : begin
            case (funct3) 
                3'b000 : begin
                    if ({op5, funct7_5} == 2'b11) begin
                        ALUControl = ALU_SUB;
                    end 
                    else begin 
                        ALUControl = ALU_ADD; 
                    end 
                end
                3'b010 : begin
                    ALUControl = ALU_SLT; // slt 
                end
                3'b110 : begin
                    ALUControl = ALU_OR; // or 
                end
                3'b111 : begin
                    ALUControl = ALU_AND; 
                end
                default : ALUControl = ALU_ADD;
            endcase 
        end 
        default : ALUControl = ALU_ADD;
    endcase 
end 


endmodule
