`timescale 1ns/1ps
module control
import riscv_pkg::*;
(
    input logic clk,
    input logic rst_n,
    input logic Zero,
    input opcode_t op, 
    input logic [2:0] funct3,
    input logic funct7_5,

    output logic RegWrite, 
    output logic MemWrite, 
    output logic IRWrite, 
    output logic PCWrite,
    output logic [1:0] ResultSrc,
    output logic [1:0] ALUSrcB, 
    output logic [1:0] ALUSrcA,
    output alu_control_t ALUControl,
    output logic [2:0] ImmSrc,

    // Hart Interface  (from DM)
    input  logic hart_halt_req,
    input  logic hart_resume_req,
    output logic hart_halted,

    // Progbuf interface
    input  logic progbuf_exec,
    output logic progbuf_done, 

    output logic tmr_fsm_error
);

logic Branch;
logic PCUpdate;

logic branch_condition ;
assign branch_condition = Zero ^ (funct3[0] ^ funct3[2]);
assign PCWrite = (branch_condition && Branch) || PCUpdate;

logic ForceAdd; 

tmr_main_fsm u_fsm (
    .clk(clk),
    .rst_n(rst_n),
    .op(op),
    .hart_halt_req(hart_halt_req),
    .hart_resume_req(hart_resume_req),
    .hart_halted(hart_halted),
    .progbuf_exec(progbuf_exec),
    .progbuf_done(progbuf_done),
    .Branch(Branch),
    .PCUpdate(PCUpdate),
    .RegWrite(RegWrite),
    .MemWrite(MemWrite),
    .IRWrite(IRWrite),
    .ResultSrc(ResultSrc),
    .ALUSrcB(ALUSrcB),
    .ALUSrcA(ALUSrcA),
    .ForceAdd(ForceAdd),
    .tmr_error(tmr_fsm_error)
);

alu_decoder u_alu(
    .opcode(op),
    .funct3(funct3),
    .funct7_5(funct7_5),
    .ForceAdd(ForceAdd),
    .ALUControl_out(ALUControl)
);

instr_decoder u_instr(
    .opcode(op),
    .ImmSrc(ImmSrc)
);

endmodule 
