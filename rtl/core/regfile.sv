`timescale 1ns/1ps
module regfile (
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
    output logic [31:0] rd2

);

logic [31:0] registers [0:31]; 

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (int i=0; i < 32; i++) begin
            registers[i] <= 32'b0;
        end 
    end else begin 
        if (hart_regfile_we && hart_regfile_addr != 0) begin 
            registers[hart_regfile_addr] <= hart_regfile_wdata;
        end else if (we3 && a3 != 0) begin
            registers[a3] <= wd3;
        end
    end 
end

assign rd1 = registers[a1];
assign rd2 = registers[a2];

assign hart_regfile_rdata = registers[hart_regfile_addr];

endmodule 