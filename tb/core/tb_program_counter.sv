`timescale 1ns/1ps
module tb_program_counter;
logic clk; 
logic rst_n; 
logic [31:0] PCNext;
logic PCWrite;
logic dbg_pc_we;
logic [31:0] dbg_pc_wdata;

logic [31:0] dbg_pc_rdata;
logic [31:0] pc;

program_counter dut(
    .clk(clk),
    .rst_n(rst_n),
    .PCNext(PCNext), 
    .PCWrite(PCWrite),
    .dbg_pc_we(dbg_pc_we),
    .dbg_pc_wdata(dbg_pc_wdata),
    .dbg_pc_rdata(dbg_pc_rdata),
    .pc(pc)
);

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(1, tb_program_counter);
end
always #5 clk = ~clk;
initial begin 
    clk = 0;
    rst_n = 0;
    PCWrite = 0; 
    dbg_pc_we = 0;
    PCNext = 0;
    dbg_pc_wdata = 0;

    repeat(2) @(posedge clk);
    if(pc != 0) 
        $error("❌ Reset failed");
    
    rst_n = 1;
    
    @(negedge clk);
    PCNext = 32'h100;
    PCWrite = 1;

    repeat(2) @(posedge clk); 
    if(pc != 32'h100) 
        $error("❌ PCWrite failed");

    PCWrite = 0;
    PCNext = 32'h200; 
    @(posedge clk);
    if(pc != 32'h100) 
        $error("❌ PC hold failed");

    @(negedge clk);
    dbg_pc_we = 1;
    dbg_pc_wdata = 32'hABC;

    repeat(2) @(posedge clk); 
    if (pc != 32'hABC)
        $error("❌ Debug write failed");

    if (dbg_pc_rdata != pc)
        $error("❌ Debug read mismatch");
        
    dbg_pc_we = 0;
    $display("✅ All program_counter tests passed");
    $finish;

end 
endmodule