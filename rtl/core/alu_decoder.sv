`timescale 1ns/1ps
module alu_decoder (
    input logic [6:0] opcode, 
    input logic [2:0] funct3, 
    input logic funct7_5,
    input logic ForceAdd,

    output alu_control_t ALUControl_out 
);

import riscv_pkg::*;
alu_control_t ALUControl;  
assign ALUControl_out = ForceAdd ? ALU_ADD : ALUControl;

always_comb begin
    // H&H Appendix B. RISC-V Instruction Set Summary
    case (opcode) 
        7'd3 : ALUControl = ALU_ADD; // LOAD
        7'd19: begin // I-TYPE
            case(funct3) 
                3'b000: ALUControl = ALU_ADD;   // addi
                3'b010: ALUControl = ALU_SLT;   // slti
                3'b011: ALUControl = ALU_SLTU;  // sltiu
                3'b100: ALUControl = ALU_XOR;   // xori
                3'b110: ALUControl = ALU_OR;    // ori
                3'b111: ALUControl = ALU_AND;   // andi
                3'b001: ALUControl = ALU_SLL;
                3'b101: begin
                    if (funct7_5) ALUControl = ALU_SRA; 
                    else ALUControl = ALU_SRL;
                end 
                default : ALUControl = ALU_ADD; 
            endcase 

        end 

        7'd35 : ALUControl = ALU_ADD; // STORES 

        7'd51 : begin // R-TYPE
            case (funct3)
                3'b000: begin
                    if (funct7_5)
                        ALUControl = ALU_SUB;
                    else
                        ALUControl = ALU_ADD;
                end

                3'b001: ALUControl = ALU_SLL;
                3'b010: ALUControl = ALU_SLT;
                3'b011: ALUControl = ALU_SLTU;
                3'b100: ALUControl = ALU_XOR;

                3'b101: begin
                    if (funct7_5)
                        ALUControl = ALU_SRA;
                    else
                        ALUControl = ALU_SRL;
                end

                3'b110: ALUControl = ALU_OR;
                3'b111: ALUControl = ALU_AND;

                default: ALUControl = ALU_ADD;
            endcase 
            
                
        end 
        7'd99 : begin // BRANCH 
            case (funct3[2:1]) 
                2'b00 : ALUControl = ALU_SUB;  // BEQ, BNE
                2'b10 : ALUControl = ALU_SLT;  // BLT, BGE
                2'b11 : ALUControl = ALU_SLTU; // BLTU, BGEU
                default: ALUControl = ALU_SUB;
            endcase 

        end 
        
        

        default : ALUControl = ALU_ADD;
    endcase 
end 


endmodule
