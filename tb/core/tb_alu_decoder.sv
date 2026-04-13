module tb_alu_decoder;
import riscv_pkg::*;
logic op5;
logic [2:0] funct3;
logic funct7_5;
logic [1:0] ALUOp;
alu_control_t ALUControl;
alu_decoder dut(
    .op5(op5),
    .funct3(funct3),
    .funct7_5(funct7_5),
    .ALUOp(ALUOp),
    .ALUControl(ALUControl)
);

initial begin 
    $dumpfile("wave.vcd");
    $dumpvars(1, tb_alu_decoder);
end 

initial begin 
    ALUOp = 2'b00;
    # 10;
    if (ALUControl != ALU_ADD)
        $error("ALD_ADD failed");

    ALUOp = 2'b01;
    #10;
    if(ALUControl != ALU_SUB) 
        $error ("ALU_SUB failed");

    ALUOp = 2'b10;
    #10; 
    if (ALUControl !=ALU_ADD)
        $error("Default failed");
    
    ALUOp = 2'b10; 
    funct3 = 3'b000;
    {op5, funct7_5} = 2'b11;
    #10;
    if(ALUControl != ALU_SUB) 
        $error("ALU_SUB failed");

    ALUOp = 2'b10; 
    funct3 = 3'b000;
    {op5, funct7_5} = 2'b00;
    #10;
    if(ALUControl != ALU_ADD) 
        $error("ALU_ADD failed");

    ALUOp = 2'b10; 
    funct3 = 3'b000;
    {op5, funct7_5} = 2'b01;
    #10;
    if(ALUControl != ALU_ADD) 
        $error("ALU_ADD failed");

    ALUOp = 2'b10; 
    funct3 = 3'b000;
    {op5, funct7_5} = 2'b10;
    #10;
    if(ALUControl != ALU_ADD) 
        $error("ALU_ADD failed");

    ALUOp = 2'b10; 
    funct3 = 3'b010;
    #10;
    if(ALUControl != ALU_SLT) 
        $error("ALU_SLT failed");

    ALUOp = 2'b10; 
    funct3 = 3'b110;
    #10;
    if(ALUControl != ALU_OR) 
        $error("ALU_OR failed");

    ALUOp = 2'b10; 
    funct3 = 3'b111;
    #10;
    if(ALUControl != ALU_AND) 
        $error("ALU_AND failed");

    $display("All tests passed ✅");
    $finish;
end 
endmodule