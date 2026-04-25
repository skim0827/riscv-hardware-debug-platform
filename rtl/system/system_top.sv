/*
Description : 
- JTAG TAP 
- DTM (Debug Transport Module)
- Debug Module V2 
- CPU Core 

Interface : 
- JTAG pins : tck, tdi, tdo, tms (to external debugger)
- System clock : clk, rst_n
- DMI bus 
- Hart Interface 

Architecture : 
JTAG Debugger 
    |
  TAP FSM 
    |
   DTM 
    |
   DM 
    |
   CPU 

*/
`timescale 1ns/1ps

module system_top(
    input logic clk,
    input logic rst_n,

    input logic tck,
    input logic tms,
    input logic tdi,
    output logic tdo
);

import dmi_pkg::*;
import riscv_pkg::*;
// ============================================================================
// TAP control signals  (tck domain)
// ============================================================================
logic capture_dr, shift_dr, update_dr;
logic capture_ir, shift_ir, update_ir;

// ============================================================================
// DMI bus — TCK domain  (DTM outputs)
// ============================================================================
logic [6:0]  tck_dmi_addr;
logic [31:0] tck_dmi_wdata;
logic        tck_dmi_we;
logic        tck_dmi_re;
logic [31:0] tck_dmi_rdata;   // DM → DTM (synchronised back to tck)

// ============================================================================
// DMI bus — CLK domain  (DM inputs, from bridge)
// ============================================================================
logic [6:0]  clk_dmi_addr;
logic [31:0] clk_dmi_wdata;
logic [1:0]  clk_dmi_op;
logic        clk_dmi_we;
logic        clk_dmi_re;
logic        clk_dmi_valid;
logic [31:0] clk_dmi_rdata;   // DM output, fed back through bridge

// ============================================================================
// DTMCS feedback  (tck domain, driven by DTM parameters)
// TODO: drive dtmcs_dmistat from DM busy/error status once DM exposes it
// ============================================================================
logic        dtmcs_dmihardreset; 
logic        dtmcs_dmireset; 
logic [2:0]  dtmcs_idle;
logic [1:0]  dtmcs_dmistat; 
logic [5:0]  dtmcs_abits; 

assign dtmcs_idle    = 3'b001;   // 1 run-test/idle cycle between accesses
assign dtmcs_dmistat = 2'b00;    // no error — placeholder until DM drives this
assign dtmcs_abits   = 6'd7;     // 7-bit address field

// ============================================================================
// Hart interface  (clk domain)
// ============================================================================

logic        hart_halted;
logic        hart_halt_req;
logic        hart_resume_req;
logic        hart_reset_req;

logic [31:0] hart_regfile_rdata;
logic [31:0] hart_regfile_wdata;
logic [4:0]  hart_regfile_addr;
logic        hart_regfile_we;

logic [31:0] hart_pc_rdata;
logic [31:0] hart_pc_wdata;
logic        hart_pc_we;

// ============================================================================
// Program buffer interface  (clk domain)
// ============================================================================
logic [31:0] progbuf_instr;
logic        progbuf_exec;
logic        progbuf_done;
logic        progbuf_exception;


// ============================================================================
// TAP FSM
// ============================================================================
tap_fsm tap_controller(
    .tck(tck),
    .tms(tms),

    .capture_ir(capture_ir),
    .shift_ir(shift_ir),
    .update_ir(update_ir),

    .capture_dr(capture_dr),
    .shift_dr(shift_dr),
    .update_dr(update_dr)
);

// ============================================================================
// DTM  (tck domain)
// ============================================================================
dtm_top #(
    .WIDTH(32),
    .DTMCS_WIDTH(32),
    .DMI_WIDTH(41), 
    .IDCODE_WIDTH(32)
)dtm (
    // JTAG interface 
    .tck(tck), 
    .tdi(tdi), 
    .tdo(tdo),

    // JTAG TAP 
    .capture_ir(capture_ir),
    .shift_ir(shift_ir),
    .update_ir(update_ir),
    .capture_dr(capture_dr), 
    .shift_dr(shift_dr), 
    .update_dr(update_dr), 

    // DMI Bus 
    .dmi_addr(tck_dmi_addr), 
    .dmi_wdata(tck_dmi_wdata),
    .dmi_we(tck_dmi_we),
    .dmi_re(tck_dmi_re), 
    .dmi_rdata(tck_dmi_rdata), // synchronised return value

    // DTMCS (section 6.1.4)
    .dtmcs_dmihardreset(dtmcs_dmihardreset), 
    .dtmcs_dmireset(dtmcs_dmireset), 
    .dtmcs_idle(dtmcs_idle), 
    .dtmcs_dmistat(dtmcs_dmistat),
    .dtmcs_abits(dtmcs_abits)
);

// ============================================================================
// DMI CDC bridge  (tck ↔ clk)
// ============================================================================
dmi_cdc_bridge cdc_bridge (
    .tck            (tck),
    .clk            (clk),
    .rst_n          (rst_n),

    // TCK side (from DTM)
    .tck_dmi_addr   (tck_dmi_addr),
    .tck_dmi_wdata  (tck_dmi_wdata),
    .tck_dmi_we     (tck_dmi_we),
    .tck_dmi_re     (tck_dmi_re),
    .tck_dmi_rdata  (tck_dmi_rdata),   // back to DTM

    // CLK side (to DM)
    .clk_dmi_addr   (clk_dmi_addr),
    .clk_dmi_wdata  (clk_dmi_wdata),
    .clk_dmi_op     (clk_dmi_op),
    .clk_dmi_we     (clk_dmi_we),
    .clk_dmi_re     (clk_dmi_re),
    .clk_dmi_valid  (clk_dmi_valid),
    .clk_dmi_rdata  (clk_dmi_rdata)    // from DM
);



// ============================================================================
// Debug Module  (clk domain)
// ============================================================================

debug_module dm (
    .clk(clk),
    .rst_n(rst_n),
    
    .dmi_addr(clk_dmi_addr),
    .dmi_wdata(clk_dmi_wdata),
    .dmi_we(clk_dmi_we),
    .dmi_re(clk_dmi_re), 
    .dmi_rdata(clk_dmi_rdata),
    .dmi_valid(clk_dmi_valid),


    // Hart Interface (to CPU Core)    
    .hart_halted(hart_halted),
    .hart_halt_req(hart_halt_req),
    .hart_resume_req(hart_resume_req),
    .hart_reset_req(hart_reset_req),
    // GPS 
    .hart_regfile_rdata(hart_regfile_rdata),
    .hart_regfile_wdata(hart_regfile_wdata),
    .hart_regfile_addr(hart_regfile_addr), 
    .hart_regfile_we(hart_regfile_we),


    .hart_pc_rdata(hart_pc_rdata),
    .hart_pc_wdata(hart_pc_wdata),
    .hart_pc_we(hart_pc_we), 

    .progbuf_instr(progbuf_instr),
    .progbuf_exec(progbuf_exec),
    .progbuf_done(progbuf_done),
    .progbuf_exception(progbuf_exception)
);

// ============================================================================
// CPU core  (clk domain)
// ============================================================================
cpu cpu_core (
    .clk(clk), 
    .rst_n(rst_n), 

    // hart interface 
    .hart_halt_req(hart_halt_req),
    .hart_resume_req(hart_resume_req),
    .hart_reset_req(1'b0), // for multi hart system
    .hart_halted(hart_halted),

    .hart_regfile_addr(hart_regfile_addr),
    .hart_regfile_wdata(hart_regfile_wdata),
    .hart_regfile_we(hart_regfile_we), 
    .hart_regfile_rdata(hart_regfile_rdata),

    .hart_pc_wdata(hart_pc_wdata),
    .hart_pc_we(hart_pc_we),
    .hart_pc_rdata(hart_pc_rdata),

    // program buffer interface 
    .progbuf_instr(progbuf_instr), 
    .progbuf_exec(progbuf_exec),
    .progbuf_done(progbuf_done),
    .progbuf_exception(progbuf_exception)
);

endmodule : system_top