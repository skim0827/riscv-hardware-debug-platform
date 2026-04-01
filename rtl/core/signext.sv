`timescale 1ns/1ps
module signext (
    input logic [24:0] raw, // 31 - 7 op 
    input logic [1:0] ImmSrc, 

    output logic [31:0] ImmExt 
);

always_comb begin 
    case (ImmSrc)
        2'b00 : ImmExt = {{20 {raw[24]}}, raw[24:13]}; // I
        2'b01 : ImmExt = {{20 {raw[24]}}, raw[24:18], raw[4:0]}; // S
        2'b10 : ImmExt = {{20 {raw[24]}}, raw[0], raw[23:18], raw[4:1],1'b1}; // B
        2'b11 : ImmExt = {{12 {raw[24]}}, raw[12:5], raw[13], raw[23:14], 1'b0}; // J
        // U ? 
        default : ImmExt = 32'b0;
    endcase 
end 

endmodule 