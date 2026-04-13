`timescale 1ns/1ps
module tb_instr_decoder ;

import riscv_pkg::*;
opcode_t opcode;
logic [1:0] ImmSrc;

instr_decoder dut (
    .op(opcode),
    .ImmSrc(ImmSrc)
); 

initial begin 
    $dumpfile("wave.vcd");
    $dumpvars(1,tb_instr_decoder);
end 

typedef struct {
    opcode_t op;
    logic [1:0] expected;
} test_vector_t;

test_vector_t tests[] = '{
    '{OPCODE_I_TYPE_LOAD, 2'b00},
    '{OPCODE_I_TYPE_ALU, 2'b00},
    '{OPCODE_S_TYPE, 2'b01},
    '{OPCODE_B_TYPE, 2'b10},
    '{OPCODE_J_TYPE, 2'b11},
    '{opcode_t'(7'b0000000), 2'b00}  // default version
};

initial begin   
    foreach (tests[i]) begin
        opcode= tests[i].op;
        #1;
        if(ImmSrc != tests[i].expected) 
            $error("❌ Test %0d failed: opcode=%b expected=%b got=%b",
                    i, tests[i].op, tests[i].expected, ImmSrc);
        
    end
    $display("✅ All tests passed");
    $finish;
end 
endmodule