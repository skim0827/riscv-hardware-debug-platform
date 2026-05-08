`timescale 1ns/1ps
import riscv_pkg::*;

module instr_decoder(
    input opcode_t opcode, 
    output logic [2:0] ImmSrc
);

always_comb begin

    case (opcode) 
        OPCODE_I_TYPE_LOAD : ImmSrc = 2'b00;
        OPCODE_I_TYPE_ALU : ImmSrc = 3'b000;
        OPCODE_I_TYPE_JALR : ImmSrc = 3'b000; 
        OPCODE_S_TYPE : ImmSrc = 3'b01;  
        OPCODE_B_TYPE : ImmSrc = 3'b010; 
        OPCODE_J_TYPE : ImmSrc = 3'b011;
        OPCODE_U_TYPE_LUI   : ImmSrc = 3'b100;
        OPCODE_U_TYPE_AUIPC : ImmSrc = 3'b100;

        default: ImmSrc = 2'b00;
    endcase

end 
endmodule
