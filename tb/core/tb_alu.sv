module tb_alu;
logic [31:0] srcA;
logic [31:0] srcB;
alu_control_t ALUControl;
logic [31:0] ALUResult;
logic Zero;

alu dut(
    .srcA(srcA),
    .srcB(srcB),
    .ALUControl(ALUControl),
    .ALUResult(ALUResult),
    .Zero(Zero)
);
import riscv_pkg::*;
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(1, tb_alu);
end
initial begin
    srcA = 10;
    srcB = 5;

    ALUControl = ALU_ADD;
    #10;
    if (ALUResult != 15)
        $error("ADD failed");

    ALUControl = ALU_SUB;
    #10;
    if (ALUResult != 5)
        $error("SUB failed");

    ALUControl = ALU_OR;
    #10;
    if (ALUResult != 15)
        $error("OR failed");

    ALUControl = ALU_AND;
    #10;
    if (ALUResult != 0 )
        $error("AND failed");


    ALUControl = ALU_SUB;
    srcA = 10 ; srcB = 10;
    #10;
    if (Zero != 1)
        $error("Zero failed");
    $display("All tests passed ✅");
    $finish;
end


endmodule