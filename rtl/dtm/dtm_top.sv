// ============================================================================
// RISC-V Debug Transport Module (DTM) - Top Level
// 
// Specification: RISC-V External Debug Support Version 0.13.2
// Section 6.1: JTAG Debug Transport Module
//
// This module implements the JTAG-based Debug Transport Module (DTM) that:
// - Translates JTAG protocol to DMI (Debug Module Interface) protocol
// - Manages IR (instruction register) and DR (data register) operations
// - Implements JTAG TAP state machine integration
// - Supports DMI read/write operations with error/busy status handling
// 
// Key Registers (per spec 6.1.2):
// - IR[4:0]:  JTAG instruction codes
//   * 0x01: IDCODE
//   * 0x10: DTMCS (DTM Control and Status)
//   * 0x11: DMI (Debug Module Interface Access)
//   * 0x1f: BYPASS
// - DR: Variable width depending on IR selection
// ============================================================================
module dtm_top #(
    parameter int WIDTH = 32, 
    parameter int DTMCS_WIDTH = 32, 
    parameter int DMI_WIDTH = 41, 
    parameter int IDCODE_WIDTH = 32
)(
    input logic tck, 
    input logic tdi, 
    output logic tdo,

    // JTAG TAP 
    input logic capture_ir,
    input logic shift_ir,
    input logic update_ir,
    input logic capture_dr, 
    input logic shift_dr, 
    input logic update_dr, 

    // DMI Interface 
    output logic [6:0]  dmi_addr, 
    output logic [31:0] dmi_wdata,
    output logic        dmi_we,
    output logic        dmi_re, 
    input  logic [31:0] dmi_rdata,

    // DTMCS (section 6.1.4)
    output logic        dtmcs_dmihardreset, 
    output logic        dtmcs_dmireset, 
    input  logic [2:0]  dtmcs_idle, 
    input  logic [1:0]  dtmcs_dmistat,
    input  logic [5:0]  dtmcs_abits  // size of addr in DMI = 7 bits 

);

import dmi_pkg::*;
// table 6.1 
localparam logic [4:0] IR_IDCODE    = 5'h01;
localparam logic [4:0] IR_DTMCS     = 5'h10;
localparam logic [4:0] IR_DMI       = 5'h11;
localparam logic [4:0] IR_BYPASS    = 5'h1f;
localparam logic [31:0] IDCODE_VALUE = 32'h12345678; // placeholder 

// registers 
// ========================================================================
// Instruction register 
logic [4:0] ir_data;
logic [4:0] ir_parallel_in;

// Data reg 
// DTMCS | DMI | IDCODE | BYPASS 
logic [DTMCS_WIDTH-1:0] dtmcs_dr_data;
logic [DMI_WIDTH-1:0] dmi_dr_data;
logic [IDCODE_WIDTH-1:0] idcode_dr_data; 
logic bypass_reg; 

// TDO 
logic ir_tdo, dr_tdo; 
logic tdo_internal; 

// decoded IR instruction 
logic select_idcode, select_dtmcs, select_dmi, select_bypass;

// DMI STATE 
// ========================================================================
typedef enum logic [1:0] {
    DMI_IDLE    = 2'b00,
    DMI_READ    = 2'b01,
    DMI_WRITE   = 2'b10, 
    DMI_BUSY    = 2'b11
} dmi_op_t; 

dmi_op_t dmi_op, dmi_op_next;

// IR capture value 
assign ir_parallel_in = 5'b00001; // 0x01 ???

// Instruction decoder 
// ========================================================================
always_comb begin : instr_decode 
    select_idcode   = 1'b0;
    select_dtmcs    = 1'b0;
    select_dmi      = 1'b0; 
    select_bypass   = 1'b0;

    case (ir_data) 
        IR_IDCODE   : select_idcode = 1'b1;
        IR_DTMCS    : select_dtmcs  = 1'b1;
        IR_DMI      : select_dmi    = 1'b1;
        IR_BYPASS   : select_bypass = 1'b1;
        default     : select_bypass = 1'b1;
    endcase 
end 

// IR : capture shift and update 
// ========================================================================
always_ff @(posedge tck) begin : ir_shift_register 
    if (capture_ir) ir_data  <= ir_parallel_in; // capture 0x01 
    else if (shift_ir) ir_data  <= {tdi, ir_data[4:1]}; // shift right 
    else if (update_ir) ; // ??? do nothing ??
end 

assign ir_tdo = ir_data[0]; // LSB 

// Data Reg - IDCODE 
// ========================================================================
always_ff @(posedge tck) begin : idcode_register
    if (capture_dr && select_idcode) idcode_dr_data <= IDCODE_VALUE;
    else if (shift_dr && select_idcode) idcode_dr_data <= {tdi, idcode_dr_data[31:1]};
    // where is update ???  i don't understand this behaviour
end 

// Data Reg - DTMCS 
// ========================================================================
always_ff @(posedge tck) begin : dtmcs_register 
    if (capture_dr && select_dtmcs) begin 
        
        dtmcs_dr_data <= {
            14'b0, 
            dtmcs_dmihardreset, 
            dtmcs_dmireset, 
            dtmcs_idle, 
            dtmcs_dmistat,
            dtmcs_abits,
            5'h1 // version 0.13
        };
    end else if (shift_dr && select_dtmcs) dtmcs_dr_data <= {tdi, dtmcs_dr_data[31:1]};
end 


// Data Reg - DMI regs 
// ========================================================================
always_ff @(posedge tck) begin : dmi_register 

    if (capture_dr && select_dmi) begin 
        dmi_dr_data <= {
            dmi_dr_data[40:34], // address 
            dmi_rdata, 
            dmi_dr_data[1:0] // op
        };
    end else if (shift_dr && select_dmi) dmi_dr_data <= {tdi, dmi_dr_data[40:1]};
end 


assign dmi_re = update_dr && select_dmi && (dmi_dr_data[1:0] == 2'b01); // pg 66 
assign dmi_we = update_dr && select_dmi && (dmi_dr_data[1:0] == 2'b10);

// BYPASS regs 
// ========================================================================
always_ff @(posedge tck) begin : bypass_register 
    if (capture_dr && select_bypass) bypass_reg  <= 1'b0; // must capture 0 per spec ?? where 
    else if (shift_dr && select_bypass) bypass_reg <= tdi; 
end 

// TDO mux : priority IR shift - selected DR - BYPASS 
// ========================================================================
always_comb begin : tdo_mux 
    if (shift_ir) tdo_internal = ir_tdo; 
    else if (shift_dr) begin 

        if (select_dmi) tdo_internal = dmi_dr_data[0];
        else if (select_dtmcs) tdo_internal = dtmcs_dr_data[0];
        else if (select_idcode) tdo_internal = idcode_dr_data[0];
        else tdo_internal = bypass_reg;
    end else tdo_internal = 1'bx; // undefined outside shift phase 
end 

assign tdo = tdo_internal;


// Control signal 
// ========================================================================
always_ff @(posedge tck) begin : control_outputs 
    if (update_dr && select_dtmcs) begin 
        dtmcs_dmihardreset <= dtmcs_dr_data[17]; 
        dtmcs_dmireset <= dtmcs_dr_data[16];

    end else begin 
        dtmcs_dmihardreset <= 1'b0;
        dtmcs_dmireset     <= 1'b0;
    end 
end 
endmodule : dtm_top 

