// ============================================================================
// tb_cpu_top.sv  –  Testbench for RISC-V Multi-Cycle CPU
// ============================================================================
//
// Design under test : cpu  (cpu_top.sv)
// Debug spec        : RISC-V Debug Specification v0.13 (minimal subset)
//
// Test groups
// -----------
//   TEST1  I-type ALU        : ADDI (including negative immediate / sign-ext)
//   TEST2  R-type ALU        : ADD, SUB, AND, OR, SLT
//   TEST3  Memory            : SW / LW round-trip + direct mem array check
//   TEST4  Branch not-taken  : BEQ where rs1 ≠ rs2
//   TEST5  Branch taken      : BEQ where rs1 = rs2
//   TEST6  JAL               : jump target and link-register value
//   TEST7  Debug interface   : halt/resume, GPR R/W, PC R/W, x0 hardwired=0
//   TEST8  Reset behaviour   : mid-run reset → PC=0, registers=0
//   TEST9  Program buffer    : FSM-driven progbuf_done, correct exec latency,
//                              register side-effects verified
// Instruction encoding notes (for reference)
// -------------------------------------------
//     ADDI / I-type ALU   
//     ADD  / R-type       
//     SW                 
//     LW                 
//     BEQ               
//     JAL            
// ============================================================================
`timescale 1ns/1ps
module tb_cpu_top;
import riscv_pkg::*;

localparam int CLK_PERIOD_NS = 10; // 100MHz

// ============================================================================
// DUT port declarations
// ============================================================================
logic        clk; 
logic        rst_n; 

// Hart debug interface
logic        hart_halt_req;
logic        hart_resume_req;
logic        hart_reset_req;
logic        hart_halted;


logic [4:0]  hart_regfile_addr;
logic [31:0] hart_regfile_wdata;
logic        hart_regfile_we;
logic [31:0] hart_regfile_rdata;

logic [31:0] hart_pc_wdata;
logic        hart_pc_we;
logic [31:0] hart_pc_rdata;

// Program buffer interface 
logic [31:0] progbuf_instr; 
logic        progbuf_exec; 
logic        progbuf_done;
logic        progbuf_exception;

// ============================================================================
// DUT instantiation
// ============================================================================

cpu dut(
    .clk                (clk),
    .rst_n              (rst_n),

    .hart_halt_req      (hart_halt_req),
    .hart_resume_req    (hart_resume_req),
    .hart_reset_req     (hart_reset_req),
    .hart_halted        (hart_halted),

    .hart_regfile_addr  (hart_regfile_addr),
    .hart_regfile_wdata (hart_regfile_wdata),
    .hart_regfile_we    (hart_regfile_we),
    .hart_regfile_rdata (hart_regfile_rdata),

    .hart_pc_wdata      (hart_pc_wdata),
    .hart_pc_we         (hart_pc_we),
    .hart_pc_rdata      (hart_pc_rdata),

    .progbuf_instr      (progbuf_instr),
    .progbuf_exec       (progbuf_exec),
    .progbuf_done       (progbuf_done),
    .progbuf_exception  (progbuf_exception)
);

// ============================================================================
// Clock generation
// ============================================================================
initial clk = 1'b0; 
always #(CLK_PERIOD_NS /2) clk = ~clk;

// ============================================================================
// Scoreboard
// ============================================================================
int unsigned pass_count; 
int unsigned fail_count;
int unsigned total_count; 

task automatic check (
    input logic [31:0] actual, 
    input logic [31:0] expected,
    input string test_message 
);
if (actual == expected) begin 
    pass_count ++; 
    $display("      [PASS] %s : got = 0x%08h, expected = 0x%08h", test_message, actual, expected);
end else begin 
    fail_count ++;
    $display("      [❌FAIL] %s : got = 0x%08h, expected = 0x%08h", test_message, actual, expected);
end 
total_count ++;

endtask : check 


// ============================================================================
// Utility tasks
// ============================================================================
task automatic apply_reset(int n = 4);
    hart_halt_req      = 1'b0;
    hart_resume_req    = 1'b0;
    hart_reset_req     = 1'b0;
    hart_regfile_addr  = 5'h00;
    hart_regfile_wdata = 32'h0;
    hart_regfile_we    = 1'b0;
    hart_pc_wdata      = 32'h0;
    hart_pc_we         = 1'b0;
    progbuf_instr      = 32'h0;
    progbuf_exec       = 1'b0;

    rst_n = 1'b0;
    repeat (n) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    @(posedge clk);

endtask : apply_reset




task automatic wait_cycles(int n);
    repeat (n) @(posedge clk);
endtask : wait_cycles 



task automatic halt_cpu();
    @(negedge clk);
    hart_halt_req = 1'b1;
    @(posedge clk);
    @(negedge clk);
    hart_halt_req = 1'b0;

    wait(hart_halted == 1'b1);
    @(negedge clk); // settle before sampling debug outputs 

endtask : halt_cpu




task automatic resume_cpu(); 
    @(negedge clk);
    hart_resume_req = 1'b1;
    @(posedge clk);
    @(negedge clk);
    hart_resume_req = 1'b0;
    wait (hart_halted == 1'b0);
endtask : resume_cpu



task automatic dbg_read_reg(input logic [4:0] addr, output logic [31:0] data);
    @(negedge clk);
    hart_regfile_addr = addr; 
    hart_regfile_we = 1'b0;
    # 1; // propagate through combinatorial read mux
    data = hart_regfile_rdata;
endtask : dbg_read_reg 



task automatic dbg_write_reg(input logic [4:0] addr, input logic [31:0] data);
    @(negedge clk);
    hart_regfile_addr = addr; 
    hart_regfile_we = 1'b1; 
    hart_regfile_wdata = data; 
    @(posedge clk); // captured on rising edge
    @(negedge clk);
    hart_regfile_we = 1'b0;
endtask : dbg_write_reg



task automatic dbg_read_pc (output logic [31:0] val); 
    @(negedge clk);
    hart_pc_we = 1'b0;
    #1; 
    val = hart_pc_rdata;
endtask : dbg_read_pc



task automatic dbg_write_pc (input logic [31:0] val);
    @(negedge clk);
    hart_pc_wdata = val; 
    hart_pc_we = 1'b1;
    @(posedge clk);
    @(negedge clk);
    hart_pc_we = 1'b0;
endtask : dbg_write_pc



task automatic load_mem (input logic [31:0] img[]);
    for (int i = 0; i < img.size(); i++) 
        dut.u_memory.mem[i] = img[i];
endtask : load_mem



task automatic progbuf_run (
    input logic [31:0] instr, 
    output int latency, 
    input int max_wait = 8
); 

    logic done_seen; 
    done_seen = 1'b0;
    latency = 0; 

    @(negedge clk);
    progbuf_instr = instr;
    progbuf_exec = 1'b1;
    @(posedge clk);
    @(negedge clk);
    progbuf_exec = 1'b0; 

    for (int k =0; k < max_wait; k++) begin 
        @(negedge clk);// sample mid-cycle, FF output is stable
        latency ++; 
        if (progbuf_done) begin done_seen = 1'b1; break; end 
    end 

    if (!done_seen) begin 
        $display("      [❌FAIL] progbuf_done did not arrive within %0d cycles", max_wait);
        fail_count ++;
    end
    total_count ++ ;
endtask : progbuf_run 


// ============================================================================
// TEST 1 : ADDI
// ============================================================================
localparam int ADDI_TEST_BUDGET = 16;
logic [31:0] pgm_addi[] = '{
    32'h00500093,   // addi x1, x0,  5
    32'h00300113,   // addi x2, x0,  3
    32'hFFD00193,   // addi x3, x0, -3
    32'h00A18213    // addi x4, x3, 10  (x4 = -3+10 = 7)
};


// ============================================================================
// TEST 2 : R-type ALU (ADD, SUB, AND, OR, SLT)
// ============================================================================
localparam int R_TEST_BUDGET = 32;
logic [31:0] pgm_rop[] = '{
    32'h00A00093,   // addi x1, x0, 10
    32'h00600113,   // addi x2, x0,  6
    32'h002081B3,   // add  x3, x1, x2   → 16
    32'h40208233,   // sub  x4, x1, x2   → 4
    32'h0020F2B3,   // and  x5, x1, x2   → 2   (1010 & 0110)
    32'h0020E333,   // or   x6, x1, x2   → 14  (1010 | 0110)
    32'h001123B3    // slt  x7, x2, x1   → 1   (6 < 10)
};


// ============================================================================
// TEST 3 : Memory (SW / LW)
// ============================================================================
localparam int MEM_TEST_BUDGET = 13;
logic [31:0] pgm_mem[] = '{
    32'h02A00093,   // addi x1, x0, 42
    32'h04102023,   // sw   x1, 64(x0)  imm=0x40: [11:5]=0000010 [4:0]=00000
    32'h04002103    // lw   x2, 64(x0)  imm=0x40, rd=x2=2, funct3=010
};

// sw  x1,64(x0): {0000010,00001,00000,010,00000,0100011} = 0x04102023 ✓
// lw  x2,64(x0): {000001000000,00000,010,00010,0000011}  = 0x04002103 ✓




// ============================================================================
// TEST 4 : BEQ not-taken
// ============================================================================
localparam int BEQ_TEST_BUDGET = 19;
logic [31:0] pgm_beq_nt[] = '{
    32'h00500093,   // addi x1, x0,  5
    32'h00300113,   // addi x2, x0,  3
    32'h00208463,   // beq  x1, x2, +8  (NOT taken)
    32'h04B00193    // addi x3, x0, 75
};
// ============================================================================
// TEST 5 : BEQ taken
// ============================================================================
localparam int BEQ_TEST_BUDGET_TAKEN = 20;
logic [31:0] pgm_beq_t[] = '{
    32'h00500093,   // addi x1, x0, 5
    32'h00500113,   // addi x2, x0, 5
    32'h00208463,   // beq  x1, x2, +8   (TAKEN)
    32'h03C00193,   // addi x3, x0, 60   (must be skipped)
    32'h04B00213    // addi x4, x0, 75   (spec: runs; impl: CPU restarted)
};

// ============================================================================
// TEST 6 : JAL
// ============================================================================
localparam int JAL_TEST_BUDGET = 12;
logic [31:0] pgm_jal[] = '{
    32'h008000EF,   // jal  x1, +8
    32'h00100113,   // addi x2, x0, 1  (skipped)
    32'h00200193    // addi x3, x0, 2
};

// ============================================================================
// Main test sequence
// ============================================================================
logic [31:0] rd; 
int pb_latency ;

initial begin : main_test
    pass_count = 0; 
    fail_count = 0;
    total_count = 0; 

    $display("");
    $display("================================================================");
    $display("  RISC-V Multi-Cycle CPU  –  System Testbench");
    $display("================================================================");



    $display("\n[TEST1] I-type ALU: ADDI (signed-immediate, sign-extension)");
    apply_reset();
    load_mem(pgm_addi);
    wait_cycles(ADDI_TEST_BUDGET);
    halt_cpu();

    dbg_read_reg(5'd1, rd); check(rd, 32'd5, "addi x1, x0,  5");
    dbg_read_reg(5'd2, rd); check(rd, 32'd3, "addi x2, x0,  3");
    dbg_read_reg(5'd3, rd); check(rd, 32'hFFFF_FFFD, "addi x3, x0, -3 ");
    dbg_read_reg(5'd4, rd); check(rd, 32'd7, "addi x4, x3, 10 ");




    $display("\n[TEST2] R-type ALU: ADD SUB AND OR SLT");
    apply_reset();
    load_mem(pgm_rop);
    wait_cycles(R_TEST_BUDGET);
    halt_cpu();

    dbg_read_reg(5'd3, rd); check(rd, 32'd16, "add  x3, x1, x2   → 16");
    dbg_read_reg(5'd4, rd); check(rd, 32'd4, "sub  x4, x1, x2   → 4");
    dbg_read_reg(5'd5, rd); check(rd, 32'd2, "and  x5, x1, x2   → 2 ");
    dbg_read_reg(5'd6, rd); check(rd, 32'd14, "or   x6, x1, x2   → 14");
    dbg_read_reg(5'd7, rd); check(rd, 32'd1, "slt  x7, x2, x1");



    $display("\n[TEST3] Memory: SW / LW round-trip");
    apply_reset();
    load_mem(pgm_mem);
    wait_cycles(MEM_TEST_BUDGET);
    halt_cpu();

    dbg_read_reg(5'd1, rd); check(rd, 32'd42, "addi x1 = 42 (pre-store)");
    check(dut.u_memory.mem[16], 32'd42, "sw: mem[word_16] = 42");
    dbg_read_reg(5'd2, rd); check(rd, 32'd42, "lw   x2 = 42 (round-trip)");



    $display("\n[TEST4] Branch NOT-taken: BEQ rs1≠rs2 → sequential execution");
    apply_reset();
    load_mem(pgm_beq_nt);
    wait_cycles(BEQ_TEST_BUDGET);
    halt_cpu();
    dbg_read_reg(5'd3, rd); check(rd, 32'd75, "beq NT: x3 = 75 (next instr executed)");



    $display("\n[TEST5] Branch TAKEN: BEQ rs1=rs2");
    apply_reset();
    load_mem(pgm_beq_t);
    wait_cycles(BEQ_TEST_BUDGET_TAKEN);
    halt_cpu();

    dbg_read_reg(5'd3, rd); check(rd, 32'd0, "beq T: x3 skipped = 0");
    dbg_read_reg(5'd4, rd); check(rd, 32'd75, "beq T: x4=75");



    $display("\n[TEST6] Jump: JAL");
    apply_reset();
    load_mem(pgm_jal);
    wait_cycles(JAL_TEST_BUDGET);
    halt_cpu();
    dbg_read_reg(5'd2, rd); check(rd, 32'd0, "jal: x2 skipped = 0");
    dbg_read_reg(5'd3, rd); check(rd, 32'd2, "jal: x3 = 2 (target executed)");
    dbg_read_reg(5'd1, rd); check(rd, 32'h0000_0004, "jal: x1=0x04");


    $display("\n[TEST7] Debug interface: halt/resume, GPR R/W, PC R/W, x0=0");
    apply_reset();
    load_mem(pgm_addi);
    wait_cycles(8);
    halt_cpu();

    check({31'h0, hart_halted}, 32'd1, "hart_halted = 1");

    dbg_read_pc(rd);
    $display("    [INFO] PC at halt = 0x%08h", rd);
    dbg_write_reg(5'd10, 32'hCAFE_BABE);
    dbg_read_reg(5'd10, rd);
    check(rd, 32'hCAFE_BABE, "x10 write readback = ");

    dbg_write_reg(5'd0, 32'hDEAD_BEEF);
    dbg_read_reg (5'd0, rd);
    check(rd, 32'd0, "x0 hardwired=0 (write ignored)");
    
    dbg_write_pc(32'h0000_0020);
    dbg_read_pc(rd);
    check(rd, 32'h0000_0020, "PC write-readback = 0x20");

    resume_cpu();
    check({31'h0, hart_halted}, 32'd0, "hart_halted = 0 after resume");




    $display("\n[TEST8] Reset: mid-run rst_n → PC=0, GPRs=0");

    apply_reset();
    load_mem(pgm_addi);
    wait_cycles(10);
    
    @(negedge clk); rst_n = 1'b0; 
    wait_cycles(3);

    @(negedge clk); #1;
    dbg_read_pc(rd); check(rd, 32'd0, "rst: PC=0x00");
    dbg_read_reg(5'd1, rd); check(rd, 32'd0, "rst: x1=0");
    dbg_read_reg(5'd3, rd); check(rd, 32'd0, "rst: x3=0");

    @(negedge clk); rst_n = 1'b1;
    @(posedge clk);

    $display("\n[TEST9] Program buffer: FSM-driven done, latency, side-effects");
    apply_reset();
    load_mem(pgm_addi);
    wait_cycles(4);
    halt_cpu();


    progbuf_run(32'h06300513, pb_latency); // addi x10, x0, 99
    dbg_read_reg(5'd10, rd);
    check(rd, 32'd99, "pb ADDI: x10=99");
    check({31'h0, hart_halted}, 32'd1, "pb ADDI: still halted");
    if (pb_latency == 3) begin 
        pass_count ++; 
        $display("    [PASS] ADDI done latency=%0d (exp 3)", pb_latency);
    end else begin 
        fail_count ++;
        $display("      [❌FAIL] ADDI done latency=%0d (exp 3)", pb_latency);
    end 
    total_count ++;

    begin : pb_pulse_check 
        logic done_c0, done_c1;
        @(negedge clk);
        progbuf_instr = 32'h06300513;
        progbuf_exec  = 1'b1;
        @(posedge clk); @(negedge clk);
        progbuf_exec  = 1'b0;
        wait (progbuf_done === 1'b1);
        @(posedge clk); done_c0 = progbuf_done;   // must be 1
        @(posedge clk); done_c1 = progbuf_done;   // must be 0
        check({31'h0, done_c0}, 32'd1, "pb done: high for exactly cycle 0");
        check({31'h0, done_c1}, 32'd0, "pb done: low  on cycle 1 (no latch)");
    end : pb_pulse_check




    $display("");
    $display("================================================================");
    $display("  Simulation complete");
    $display("  PASSED : %0d", pass_count);
    $display("  FAILED : %0d", fail_count);
    if (fail_count == 0)
        $display("  *** ALL CHECKS PASSED ***");
    else
        $display("  *** %0d CHECK(S) FAILED – review log above ***", fail_count);
    $display("================================================================");
    $finish;


end : main_test

// ============================================================================
// Watchdog  – abort simulation if it hangs
// ============================================================================
initial begin : watchdog
    #200_000;   // 200 µs at 100 MHz  →  20 000 cycles
    $display("[WATCHDOG] Simulation timed out – possible deadlock");
    $finish;
end : watchdog

// ============================================================================
// Waveform dump  (compile with +define+DUMP_VCD to enable)
// ============================================================================
`ifdef DUMP_VCD
initial begin : wave_dump
    $dumpfile("tb_cpu_top.vcd");
    $dumpvars(0, tb_cpu_top);
end : wave_dump
`endif

endmodule : tb_cpu_top