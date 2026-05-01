`timescale 1ns/1ps
module memory #(
    parameter WORDS = 128, 
    parameter mem_init = ""
) (
    input clk,
    input rst_n, 

    input logic [31:0] a,
    input logic [31:0] wd, 
    input logic we, // MemWrite 

    output logic [31:0] rd
);

logic [31:0] mem [0:WORDS - 1];
always_ff @(posedge clk) begin 
    if (rst_n == 0) begin
        for (int i = 0; i < WORDS; i++ ) begin 
            mem[i] <= 32'b0;
        end
    end
    else if (we) begin
        if (a[1:0] == 0) begin // address is multiple of 4
            mem[a[8:2]]<= wd;
        end
    end 

end 

// a[1:0] byte offset (ignored for word access)
// a[8:2] word index (7 bits → 128 entries)

always_comb begin 
    rd = mem[a[8:2]]; // aligned read 
end

endmodule 