`timescale 1ns/1ps
module tmr_regfile (
    input logic clk,
    input logic rst_n, 

    input logic [4:0]  a1,
    input logic [4:0]  a2,
    input logic [4:0]  a3, 
    input logic [31:0] wd3, // write data 
    input logic        we3, // write enable

    // hart interface (from DM)
    input  logic        hart_regfile_we,
    input  logic [4:0]  hart_regfile_addr,
    input  logic [31:0] hart_regfile_wdata,
    output logic [31:0] hart_regfile_rdata,


    output logic [31:0] rd1,
    output logic [31:0] rd2, 

    output logic tmr_error
);
logic [31:0] rd1_0, rd1_1, rd1_2;
logic [31:0] rd2_0, rd2_1, rd2_2;
logic [31:0] hart_rdata_0, hart_rdata_1, hart_rdata_2;

regfile u_rf_0 (
    .clk(clk), .rst_n(rst_n),
    .a1(a1), .a2(a2), .a3(a3), .wd3(wd3), .we3(we3),
    .hart_regfile_we(hart_regfile_we),
    .hart_regfile_addr(hart_regfile_addr),
    .hart_regfile_wdata(hart_regfile_wdata),
    .hart_regfile_rdata(hart_rdata_0),
    .rd1(rd1_0), .rd2(rd2_0)
);
regfile u_rf_1 (
    .clk(clk), .rst_n(rst_n),
    .a1(a1), .a2(a2), .a3(a3), .wd3(wd3), .we3(we3),
    .hart_regfile_we(hart_regfile_we),
    .hart_regfile_addr(hart_regfile_addr),
    .hart_regfile_wdata(hart_regfile_wdata),
    .hart_regfile_rdata(hart_rdata_1),
    .rd1(rd1_1), .rd2(rd2_1)
);

regfile u_rf_2 (
    .clk(clk), .rst_n(rst_n),
    .a1(a1), .a2(a2), .a3(a3), .wd3(wd3), .we3(we3),
    .hart_regfile_we(hart_regfile_we),
    .hart_regfile_addr(hart_regfile_addr),
    .hart_regfile_wdata(hart_regfile_wdata),
    .hart_regfile_rdata(hart_rdata_2),
    .rd1(rd1_2), .rd2(rd2_2)
);

assign rd1 = (rd1_0 & rd1_1) | (rd1_0 & rd1_2) | (rd1_1 & rd1_2);
assign rd2 = (rd2_0 & rd2_1) | (rd2_0 & rd2_2) | (rd2_1 & rd2_2);
assign hart_regfile_rdata = (hart_rdata_0 & hart_rdata_1) |
                             (hart_rdata_0 & hart_rdata_2) |
                             (hart_rdata_1 & hart_rdata_2);

assign tmr_error =
    |(rd1_0 ^ rd1_1) | |(rd1_1 ^ rd1_2) |
    |(rd2_0 ^ rd2_1) | |(rd2_1 ^ rd2_2) |
    |(hart_rdata_0 ^ hart_rdata_1) | |(hart_rdata_1 ^ hart_rdata_2);

    
endmodule 