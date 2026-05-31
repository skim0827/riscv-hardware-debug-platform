`timescale 1ns/1ps
module health_monitor (
    input  logic clk,
    input  logic rst_n,

    input  logic imem_corrected,
    input  logic imem_detected,
    input  logic dmem_corrected,
    input  logic dmem_detected,
    input  logic tmr_pc_error,
    input  logic tmr_fsm_error,
    input  logic tmr_rf_error,
    input  logic tmr_ir_error,

    output logic [31:0] ecc_corr_cnt_o,    // HEALTH_ECC_CORR_CNT
    output logic [31:0] ecc_det_cnt_o,     // HEALTH_ECC_DET_CNT
    output logic [31:0] tmr_pc_cnt_o,      // HEALTH_TMR_PC_CNT
    output logic [31:0] tmr_fsm_cnt_o,     // HEALTH_TMR_FSM_CNT
    output logic [31:0] tmr_rf_cnt_o,      // HEALTH_TMR_RF_CNT
    output logic [31:0] tmr_ir_cnt_o,      // HEALTH_TMR_IR_CNT
    output logic [31:0] status_o,          // HEALTH_STATUS  — live wire values
    output logic [31:0] irq_status_o,      // HEALTH_IRQ_STATUS — latched events

    input  logic [31:0] irq_mask_i,        // HEALTH_IRQ_MASK   — from slave register
    input  logic        irq_clear_i,       // pulse from slave when W1C write happens
    input  logic [31:0] irq_clear_bits_i,  // which IRQ_STATUS bits to clear
    input  logic        cnt_clear_i,       // pulse from slave: CTRL bit[0] clear all

    output logic        health_irq
);

function automatic logic [31:0] sat_inc(input logic [31:0] val);
    return (val == 32'hFFFF_FFFF) ? val : val + 1'b1;
endfunction

logic [31:0] ecc_corr_cnt;
logic [31:0] ecc_det_cnt;
logic [31:0] tmr_pc_cnt;
logic [31:0] tmr_fsm_cnt;
logic [31:0] tmr_rf_cnt;
logic [31:0] tmr_ir_cnt;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || cnt_clear_i) begin
        ecc_corr_cnt <= 32'b0;
        ecc_det_cnt  <= 32'b0;
        tmr_pc_cnt   <= 32'b0;
        tmr_fsm_cnt  <= 32'b0;
        tmr_rf_cnt   <= 32'b0;
        tmr_ir_cnt   <= 32'b0;
    end else begin
        if (imem_corrected || dmem_corrected) ecc_corr_cnt <= sat_inc(ecc_corr_cnt);
        if (imem_detected  || dmem_detected)  ecc_det_cnt  <= sat_inc(ecc_det_cnt);
        if (tmr_pc_error)                      tmr_pc_cnt   <= sat_inc(tmr_pc_cnt);
        if (tmr_fsm_error)                     tmr_fsm_cnt  <= sat_inc(tmr_fsm_cnt);
        if (tmr_rf_error)                      tmr_rf_cnt   <= sat_inc(tmr_rf_cnt);
        if (tmr_ir_error)                      tmr_ir_cnt   <= sat_inc(tmr_ir_cnt);
    end
end


assign ecc_corr_cnt_o = ecc_corr_cnt;
assign ecc_det_cnt_o  = ecc_det_cnt;
assign tmr_pc_cnt_o   = tmr_pc_cnt;
assign tmr_fsm_cnt_o  = tmr_fsm_cnt;
assign tmr_rf_cnt_o   = tmr_rf_cnt;
assign tmr_ir_cnt_o   = tmr_ir_cnt;

// STATUS register — live wire snapshot
//
// Bit assignments:
//   [0] imem_corrected
//   [1] imem_detected
//   [2] dmem_corrected
//   [3] dmem_detected
//   [4] tmr_pc_error
//   [5] tmr_fsm_error
//   [6] tmr_rf_error
//   [7] tmr_ir_error
//   [31:8] reserved, read as 0

assign status_o = {
    24'b0,
    tmr_ir_error,
    tmr_rf_error,
    tmr_fsm_error,
    tmr_pc_error,
    dmem_detected,
    dmem_corrected,
    imem_detected,
    imem_corrected
};


logic [31:0] irq_status;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        irq_status <= 32'b0;
    end else begin
        if (irq_clear_i)
            irq_status <= irq_status & ~irq_clear_bits_i;
        if (imem_corrected) irq_status[0] <= 1'b1;
        if (imem_detected)  irq_status[1] <= 1'b1;
        if (dmem_corrected) irq_status[2] <= 1'b1;
        if (dmem_detected)  irq_status[3] <= 1'b1;
        if (tmr_pc_error)   irq_status[4] <= 1'b1;
        if (tmr_fsm_error)  irq_status[5] <= 1'b1;
        if (tmr_rf_error)   irq_status[6] <= 1'b1;
        if (tmr_ir_error)   irq_status[7] <= 1'b1;
    end
end

assign irq_status_o = irq_status;

assign health_irq = |(irq_status & irq_mask_i);

endmodule
