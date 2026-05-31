`timescale 1ns/1ps

module program_counter (
    input logic         clk, 
    input logic         rst_n,
    input logic  [31:0] PCNext,
    input logic         PCWrite,

    // hart interface (from DM)
    input logic         hart_pc_we,
    input logic  [31:0] hart_pc_wdata,
    output logic [31:0] hart_pc_rdata,

    output logic [31:0] pc  
); 

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc <= 32'b0;
    end else begin 
        if (hart_pc_we) begin
            pc <= hart_pc_wdata;
        end 
        else if (PCWrite)begin 
            pc <= PCNext;
        end 
    end 
    
end 

assign hart_pc_rdata = pc ;
endmodule 
