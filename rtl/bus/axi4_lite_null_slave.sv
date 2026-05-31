`timescale 1ns/1ps
// =============================================================================
// axi4_lite_null_slave.sv
//
// A minimal AXI4-Lite slave that accepts any transaction and returns DECERR.
//
// The data crossbar has 5 slave slots, one of which is SLV_IMEM (slot 0).
// IMEM is connected directly to the CPU's instruction fetch port and is
// intentionally NOT accessible via the data bus.
// =============================================================================

module axi4_lite_null_slave (
    input  logic clk,
    input  logic rst_n,

    // Write address
    input  logic [31:0] s_awaddr,
    input  logic        s_awvalid,
    output logic        s_awready,

    // Write data
    input  logic [31:0] s_wdata,
    input  logic [3:0]  s_wstrb,
    input  logic        s_wvalid,
    output logic        s_wready,

    // Write response
    output logic [1:0]  s_bresp,
    output logic        s_bvalid,
    input  logic        s_bready,

    // Read address
    input  logic [31:0] s_araddr,
    input  logic        s_arvalid,
    output logic        s_arready,

    // Read data
    output logic [31:0] s_rdata,
    output logic [1:0]  s_rresp,
    output logic        s_rvalid,
    input  logic        s_rready
);

import axi4_lite_pkg::*;

// =============================================================================
// Write path — accept address + data in one cycle, return DECERR
// =============================================================================
typedef enum logic [1:0] { WR_IDLE, WR_RESP } wr_t;
wr_t wr_state;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) wr_state <= WR_IDLE;
    else case (wr_state)
        WR_IDLE: if (s_awvalid && s_wvalid) wr_state <= WR_RESP;
        WR_RESP: if (s_bready)              wr_state <= WR_IDLE;
        default: wr_state <= WR_IDLE;
    endcase
end

assign s_awready = (wr_state == WR_IDLE);
assign s_wready  = (wr_state == WR_IDLE);
assign s_bvalid  = (wr_state == WR_RESP);
assign s_bresp   = AXI_RESP_DECERR;

// =============================================================================
// Read path — accept address, return DECERR with 0xDEAD_BEEF
// =============================================================================
typedef enum logic [1:0] { RD_IDLE, RD_RESP } rd_t;
rd_t rd_state;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) rd_state <= RD_IDLE;
    else case (rd_state)
        RD_IDLE: if (s_arvalid) rd_state <= RD_RESP;
        RD_RESP: if (s_rready)  rd_state <= RD_IDLE;
        default: rd_state <= RD_IDLE;
    endcase
end

assign s_arready = (rd_state == RD_IDLE);
assign s_rvalid  = (rd_state == RD_RESP);
assign s_rdata   = 32'hDEAD_BEEF; 
assign s_rresp   = AXI_RESP_DECERR;

// Suppress Verilator unused input warnings
logic _unused;
assign _unused = |s_awaddr | |s_wdata | |s_wstrb | |s_araddr;

endmodule
