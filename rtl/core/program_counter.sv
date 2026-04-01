`timescale 1ns/1ps

module program_counter (
    input logic clk, 
    input logic rst_n,
    input logic [31:0] PCNext,
    input logic PCWrite,

    //debug 
    input logic dbg_pc_we,
    input logic [31:0] dbg_pc_wdata,

    output logic [31:0] dbg_pc_rdata,
    output logic [31:0] pc  
); 

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc <= 32'b0;
    end else begin 
        if (dbg_pc_we) begin
            pc <= dbg_pc_wdata;
        end 
        else if (PCWrite)begin // else if (dbg_mode == 0 && PCWrite == 1) ?? 
            pc <= PCNext;
        end 
    end 
    
end 
assign dbg_pc_rdata = pc ;
endmodule 