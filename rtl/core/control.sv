`timescale 1ns/1ps
module control(
    input logic clk,
    input logic rst_n,
    input logic Zero,
    input opcode_t op, 
    input logic [2:0] funct3,
    input logic funct7_5,

    output logic PCWrite, 
    output logic RegWrite, 
    output logic MemWrite, 
    output logic IRWrite, 
    output logic [1:0] ResultSrc,
    output logic [1:0] ALUSrcB, 
    output logic [1:0] ALUSrcA,
    output logic AdrSrc,
    output alu_control_t ALUControl,
    output logic [1:0] ImmSrc,

    // Hart Interface  (from DM)
    input  logic hart_halt_req,
    input  logic hart_resume_req,
    output logic hart_halted
);

import riscv_pkg::*;
logic [1:0] ALUOp;
logic Branch;
logic PCUpdate;
assign PCWrite = (Zero && Branch) || PCUpdate;

main_fsm u_fsm (
    .clk(clk),
    .rst_n(rst_n),
    .op(op),
    .hart_halt_req(hart_halt_req),
    .hart_resume_req(hart_resume_req),
    .hart_halted(hart_halted),
    .Branch(Branch),
    .PCUpdate(PCUpdate),
    .RegWrite(RegWrite),
    .MemWrite(MemWrite),
    .IRWrite(IRWrite),
    .ResultSrc(ResultSrc),
    .ALUSrcB(ALUSrcB),
    .ALUSrcA(ALUSrcA),
    .AdrSrc(AdrSrc),
    .ALUOp(ALUOp)
);

alu_decoder u_alu(
    .op5(op[5]),
    .funct3(funct3),
    .funct7_5(funct7_5),
    .ALUOp(ALUOp),
    .ALUControl(ALUControl)
);

instr_decoder u_instr(
    .op(op),
    .ImmSrc(ImmSrc)
);

endmodule 
