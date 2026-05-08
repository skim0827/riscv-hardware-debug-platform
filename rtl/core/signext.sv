`timescale 1ns/1ps
module signext (
    input logic [24:0] raw, // 31 - 7 op 
    input logic [2:0] ImmSrc, 

    output logic [31:0] ImmExt 
);

always_comb begin 
    // table 7.5 (H&H)
    case (ImmSrc)
        3'b000 : ImmExt = {{20 {raw[24]}}, raw[24:13]}; // I
        3'b001 : ImmExt = {{20 {raw[24]}}, raw[24:18], raw[4:0]}; // S
        3'b010 : ImmExt = {{20 {raw[24]}}, raw[0], raw[23:18], raw[4:1],1'b0}; // B
        3'b011 : ImmExt = {{12 {raw[24]}}, raw[12:5], raw[13], raw[23:14], 1'b0}; // J
        3'b100 : ImmExt = {raw[24:5], 12'b0}; // U 
        default : ImmExt = 32'b0;
    endcase 
end 

endmodule 