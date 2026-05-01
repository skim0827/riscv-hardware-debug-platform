`timescale 1ns/1ps
module tb_cdc_cmd_bridge;

localparam int CLK_HALF    = 5;          // clk half-period  [ns]
localparam int TCK_HALF    = 50;         // tck half-period  [ns]
localparam int TIMEOUT_CLK = 300;        // max clk cycles to wait for valid
localparam int GLOBAL_TO   = 100_000;    // global sim timeout [ns]
localparam int N_STRESS    = 20;         // random transactions in TC9

// ============================================================================
// DUT port connections
// ============================================================================
logic        tck, clk, rst_n;

logic [6:0]  tck_dmi_addr;
logic [31:0] tck_dmi_wdata;
logic        tck_dmi_we, tck_dmi_re;
logic [31:0] tck_dmi_rdata;

logic [6:0]  clk_dmi_addr;
logic [31:0] clk_dmi_wdata;
logic        clk_dmi_we, clk_dmi_re, clk_dmi_valid;

logic [6:0]  clk_dmi_addr;
logic [31:0] clk_dmi_wdata;
logic        clk_dmi_we, clk_dmi_re, clk_dmi_valid;
logic [31:0] clk_dmi_rdata;
 
// ============================================================================
// DUT instantiation
// ============================================================================
dmi_cdc_bridge dut (
    .tck            (tck),
    .clk            (clk),
    .rst_n          (rst_n),
    .tck_dmi_addr   (tck_dmi_addr),
    .tck_dmi_wdata  (tck_dmi_wdata),
    .tck_dmi_we     (tck_dmi_we),
    .tck_dmi_re     (tck_dmi_re),
    .tck_dmi_rdata  (tck_dmi_rdata),
    .clk_dmi_addr   (clk_dmi_addr),
    .clk_dmi_wdata  (clk_dmi_wdata),
    .clk_dmi_we     (clk_dmi_we),
    .clk_dmi_re     (clk_dmi_re),
    .clk_dmi_valid  (clk_dmi_valid),
    .clk_dmi_rdata  (clk_dmi_rdata)
);
// ============================================================================
// Clock generation
// ============================================================================
initial clk = 1'b0;
always #(CLK_HALF) clk = ~clk;

initial tck = 1'b0;
always  #(TCK_HALF) tck = ~tck;

// ============================================================================
// Scoreboard 
// ============================================================================
int test_count  = 0;
int error_count = 0;

// ============================================================================
// Utility
// ============================================================================
task automatic check(
    input logic cond, 
    input string label, 

)
endtask 
endmodule 