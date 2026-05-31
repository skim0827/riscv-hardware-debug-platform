`timescale 1ns/1ps
module tmr_main_fsm 
import riscv_pkg::*;
(
    input  logic clk, 
    input  logic rst_n,
    input  opcode_t op,
    

    // hart interface (from DM)
    input  logic hart_halt_req,
    input  logic hart_resume_req,
    output logic hart_halted, 


    // progbuf interface
    input  logic progbuf_exec,
    output logic progbuf_done,


    output logic Branch, 
    output logic PCUpdate,
    output logic RegWrite,
    output logic MemWrite, 
    output logic IRWrite, 

    output logic [1:0] ResultSrc, 
    output logic [1:0] ALUSrcB,
    output logic [1:0] ALUSrcA, 
    output logic       ForceAdd, 

    output logic tmr_error,

    input logic stall, 
    output logic MemRead
);

logic MemRead_0, MemRead_1, MemRead_2;
logic Branch_0,   Branch_1,   Branch_2;
logic PCUpdate_0, PCUpdate_1, PCUpdate_2;
logic RegWrite_0, RegWrite_1, RegWrite_2;
logic MemWrite_0, MemWrite_1, MemWrite_2;
logic IRWrite_0,  IRWrite_1,  IRWrite_2;
logic ForceAdd_0, ForceAdd_1, ForceAdd_2;
logic hart_halted_0,  hart_halted_1,  hart_halted_2;
logic progbuf_done_0, progbuf_done_1, progbuf_done_2;

logic [1:0] ResultSrc_0, ResultSrc_1, ResultSrc_2;
logic [1:0] ALUSrcB_0,   ALUSrcB_1,   ALUSrcB_2;
logic [1:0] ALUSrcA_0,   ALUSrcA_1,   ALUSrcA_2;


main_fsm u_fsm_0 (
    .clk(clk), .rst_n(rst_n), .op(op),
    .hart_halt_req(hart_halt_req), .hart_resume_req(hart_resume_req),
    .hart_halted(hart_halted_0),
    .progbuf_exec(progbuf_exec), .progbuf_done(progbuf_done_0),
    .Branch(Branch_0), .PCUpdate(PCUpdate_0),
    .RegWrite(RegWrite_0), .MemWrite(MemWrite_0), .IRWrite(IRWrite_0),
    .ResultSrc(ResultSrc_0), .ALUSrcB(ALUSrcB_0), .ALUSrcA(ALUSrcA_0),
    .ForceAdd(ForceAdd_0),
    .stall   (stall),
    .MemRead (MemRead_0)

);

main_fsm u_fsm_1 (
    .clk(clk), .rst_n(rst_n), .op(op),
    .hart_halt_req(hart_halt_req), .hart_resume_req(hart_resume_req),
    .hart_halted(hart_halted_1),
    .progbuf_exec(progbuf_exec), .progbuf_done(progbuf_done_1),
    .Branch(Branch_1), .PCUpdate(PCUpdate_1),
    .RegWrite(RegWrite_1), .MemWrite(MemWrite_1), .IRWrite(IRWrite_1),
    .ResultSrc(ResultSrc_1), .ALUSrcB(ALUSrcB_1), .ALUSrcA(ALUSrcA_1),
    .ForceAdd(ForceAdd_1),
    .stall   (stall),
    .MemRead (MemRead_1)
);

main_fsm u_fsm_2 (
    .clk(clk), .rst_n(rst_n), .op(op),
    .hart_halt_req(hart_halt_req), .hart_resume_req(hart_resume_req),
    .hart_halted(hart_halted_2),
    .progbuf_exec(progbuf_exec), .progbuf_done(progbuf_done_2),
    .Branch(Branch_2), .PCUpdate(PCUpdate_2),
    .RegWrite(RegWrite_2), .MemWrite(MemWrite_2), .IRWrite(IRWrite_2),
    .ResultSrc(ResultSrc_2), .ALUSrcB(ALUSrcB_2), .ALUSrcA(ALUSrcA_2),
    .ForceAdd(ForceAdd_2),
    .stall   (stall),
    .MemRead (MemRead_2)
);

assign Branch     = (Branch_0 & Branch_1) | (Branch_0 & Branch_2) | (Branch_1 & Branch_2);
assign PCUpdate   = (PCUpdate_0 & PCUpdate_1) | (PCUpdate_0 & PCUpdate_2) | (PCUpdate_1 & PCUpdate_2);
assign RegWrite   = (RegWrite_0 & RegWrite_1) | (RegWrite_0 & RegWrite_2) | (RegWrite_1 & RegWrite_2);
assign MemWrite   = (MemWrite_0 & MemWrite_1) | (MemWrite_0 & MemWrite_2) | (MemWrite_1 & MemWrite_2);
assign IRWrite    = (IRWrite_0 & IRWrite_1) | (IRWrite_0 & IRWrite_2) | (IRWrite_1 & IRWrite_2);
assign ForceAdd   = (ForceAdd_0 & ForceAdd_1) | (ForceAdd_0 & ForceAdd_2) | (ForceAdd_1 & ForceAdd_2);
assign hart_halted  = (hart_halted_0 & hart_halted_1) | (hart_halted_0 & hart_halted_2) | (hart_halted_1 & hart_halted_2);
assign progbuf_done = (progbuf_done_0 & progbuf_done_1) | (progbuf_done_0 & progbuf_done_2) | (progbuf_done_1 & progbuf_done_2);

assign ResultSrc = (ResultSrc_0 & ResultSrc_1) | (ResultSrc_0 & ResultSrc_2) | (ResultSrc_1 & ResultSrc_2);
assign ALUSrcB   = (ALUSrcB_0   & ALUSrcB_1)   | (ALUSrcB_0   & ALUSrcB_2)   | (ALUSrcB_1   & ALUSrcB_2);
assign ALUSrcA   = (ALUSrcA_0   & ALUSrcA_1)   | (ALUSrcA_0   & ALUSrcA_2)   | (ALUSrcA_1   & ALUSrcA_2);

assign MemRead = (MemRead_0 & MemRead_1) | (MemRead_0 & MemRead_2) | (MemRead_1 & MemRead_2);

assign tmr_error =
    (MemRead_0 ^ MemRead_1) | (MemRead_1 ^ MemRead_2) |
    (Branch_0   ^ Branch_1)   | (Branch_1   ^ Branch_2)   |
    (PCUpdate_0 ^ PCUpdate_1) | (PCUpdate_1 ^ PCUpdate_2) |
    (RegWrite_0 ^ RegWrite_1) | (RegWrite_1 ^ RegWrite_2) |
    (MemWrite_0 ^ MemWrite_1) | (MemWrite_1 ^ MemWrite_2) |
    (IRWrite_0  ^ IRWrite_1)  | (IRWrite_1  ^ IRWrite_2)  |
    (ForceAdd_0 ^ ForceAdd_1) | (ForceAdd_1 ^ ForceAdd_2) |
    |(ResultSrc_0 ^ ResultSrc_1) | |(ResultSrc_1 ^ ResultSrc_2) |
    |(ALUSrcB_0   ^ ALUSrcB_1)   | |(ALUSrcB_1   ^ ALUSrcB_2)   |
    |(ALUSrcA_0   ^ ALUSrcA_1)   | |(ALUSrcA_1   ^ ALUSrcA_2);

endmodule 