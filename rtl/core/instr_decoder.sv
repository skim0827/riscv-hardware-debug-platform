`timescale 1ns/1ps
import riscv_pkg::*;

module instr_decoder(
    input opcode_t op, 
    output logic [1:0] ImmSrc
);

always_comb begin

    case (op) 
        OPCODE_I_TYPE_LOAD : begin 
            ImmSrc = 2'b00;
        end 

        OPCODE_I_TYPE_ALU : begin
            ImmSrc = 2'b00;
        end 
        OPCODE_S_TYPE : begin
            ImmSrc = 2'b01;
        end 
        OPCODE_B_TYPE : begin
            ImmSrc = 2'b10;
        end 
        OPCODE_J_TYPE : begin
            ImmSrc = 2'b11;
        end 
        default: ImmSrc = 2'b00;
    endcase

end 
endmodule
