`timescale 1ns/1ps
module control
import riscv_pkg::*;
(
    input  logic clk,
    input  logic rst_n,
    input  logic Zero,
    input  opcode_t op, 
    input  logic [2:0] funct3,
    input  logic funct7_5,

    output logic RegWrite, 
    output logic MemWrite,
    output logic MemRead,
    output logic PCWrite,
    output logic [1:0] ResultSrc,
    output logic [1:0] ALUSrcB, 
    output logic [1:0] ALUSrcA,
    output alu_control_t ALUControl,
    output logic [2:0] ImmSrc,

    // Hart interface (from DM)
    input  logic hart_halt_req,
    input  logic hart_resume_req,
    output logic hart_halted,

    // Progbuf interface
    input  logic progbuf_exec,
    output logic progbuf_done, 

    output logic tmr_fsm_error,

    input  logic stall,

    // Fetch handshake
    // fetch_done: pulse from ifetch FSM when instruction word is latched.
    //             Fed into tmr_main_fsm so S_FETCH self-stalls until complete.
    // in_fetch_r: registered "FSM is in S_FETCH" signal, driven back to
    //             cpu_top to trigger arvalid one cycle after reset de-assertion.
    input  logic fetch_done,
    output logic in_fetch_r
);

logic Branch;
logic PCUpdate;
logic ForceAdd;

logic branch_condition;
assign branch_condition = Zero ^ (funct3[0] ^ funct3[2]);
assign PCWrite = (branch_condition && Branch) || PCUpdate;

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
    .MemRead(MemRead),
    .ResultSrc(ResultSrc),
    .ALUSrcB(ALUSrcB),
    .ALUSrcA(ALUSrcA),
    .ForceAdd(ForceAdd),
    .tmr_error(tmr_fsm_error),
    .stall(stall),
    .fetch_done(fetch_done),
    .in_fetch_r(in_fetch_r)
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