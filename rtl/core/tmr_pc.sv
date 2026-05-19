`timescale 1ns/1ps
module tmr_pc(
    input logic         clk, 
    input logic         rst_n,
    input logic  [31:0] PCNext,
    input logic         PCWrite,

    // hart interface (from DM)
    input logic         hart_pc_we,
    input logic  [31:0] hart_pc_wdata,
    output logic [31:0] hart_pc_rdata,

    output logic [31:0] pc , 
    output logic tmr_error
);

logic [31:0] pc_0, pc_1, pc_2;
logic [31:0] hart_pc_rdata_0, hart_pc_rdata_1, hart_pc_rdata_2;

program_counter u_pc_0 (
    .clk(clk),
    .rst_n(rst_n), 
    .PCNext(PCNext),
    .PCWrite(PCWrite),
    .hart_pc_we(hart_pc_we),
    .hart_pc_wdata(hart_pc_wdata),
    .hart_pc_rdata(hart_pc_rdata_0),
    .pc(pc_0)
); 

program_counter u_pc_1 (
    .clk(clk),
    .rst_n(rst_n), 
    .PCNext(PCNext),
    .PCWrite(PCWrite),
    .hart_pc_we(hart_pc_we),
    .hart_pc_wdata(hart_pc_wdata),
    .hart_pc_rdata(hart_pc_rdata_1),
    .pc(pc_1)
);


program_counter u_pc_2 (
    .clk(clk),
    .rst_n(rst_n), 
    .PCNext(PCNext),
    .PCWrite(PCWrite),
    .hart_pc_we(hart_pc_we),
    .hart_pc_wdata(hart_pc_wdata),
    .hart_pc_rdata(hart_pc_rdata_2),
    .pc(pc_2)
); 


assign pc = (pc_0 & pc_1) | (pc_0 & pc_2) | (pc_1 & pc_2);
assign hart_pc_rdata = (hart_pc_rdata_0 & hart_pc_rdata_1) | (hart_pc_rdata_0 & hart_pc_rdata_2) | (hart_pc_rdata_1 & hart_pc_rdata_2);

assign tmr_error = |(pc_0 ^ pc_1) | |(pc_1 ^ pc_2);

endmodule