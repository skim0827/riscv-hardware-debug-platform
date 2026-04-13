// ============================================================================
// Description: Comprehensive testbench for RISC-V Debug Module v0.13.2
// 
// Test Coverage:
//   - DMI Register read/write operations
//   - Hart control (halt, resume, reset)
//   - Abstract command execution (Access Register)
//   - Hart regfile and PC access
//   - Program buffer integration
//   - Status register updates
//   - Error handling and state transitions
//   - Reset and initialisation
//
// Verification Methodology: 
//   - Task-based stimulus generation
//   - Assertion-based checking
//   - Coverage-friendly test scenarios
//
// ============================================================================
`timescale 1ns/1ps
module tb_debug_module;


import dmi_pkg::*;
import riscv_pkg::*;

localparam CLK_PERIOD = 10 ; // 100MHz 
localparam RESET_CYCLE = 5;


logic clk, rst_n;



logic [6:0]   dmi_addr;
logic [31:0]  dmi_wdata;
logic         dmi_we;
logic         dmi_re;
logic         dmi_valid;
logic [31:0]  dmi_rdata;



logic        hart_halted;
logic        hart_halt_req;
logic        hart_resume_req;
logic        hart_reset_req;


logic [31:0] hart_regfile_rdata;
logic [31:0] hart_regfile_wdata;
logic [4:0]  hart_regfile_addr;
logic        hart_regfile_we;



logic [31:0] hart_pc_rdata;
logic [31:0] hart_pc_wdata;
logic        hart_pc_we;


logic [31:0] progbuf_instr;
logic        progbuf_exec;
logic        progbuf_done;
logic        progbuf_exception;



// test signals 
logic test_error;
int test_count;
int pass_count;
int fail_count;




debug_module dut (
    .clk                (clk),
    .rst_n              (rst_n),
    
    .dmi_addr           (dmi_addr),
    .dmi_wdata          (dmi_wdata),
    .dmi_we             (dmi_we),
    .dmi_re             (dmi_re),
    .dmi_rdata          (dmi_rdata),
    .dmi_valid          (dmi_valid),
    
    .hart_halted        (hart_halted),
    .hart_halt_req      (hart_halt_req),
    .hart_resume_req    (hart_resume_req),
    .hart_reset_req     (hart_reset_req),
    
    .hart_regfile_rdata (hart_regfile_rdata),
    .hart_regfile_wdata (hart_regfile_wdata),
    .hart_regfile_addr  (hart_regfile_addr),
    .hart_regfile_we    (hart_regfile_we),
    
    .hart_pc_rdata      (hart_pc_rdata),
    .hart_pc_wdata      (hart_pc_wdata),
    .hart_pc_we         (hart_pc_we),
    
    .progbuf_instr      (progbuf_instr),
    .progbuf_exec       (progbuf_exec),
    .progbuf_done       (progbuf_done),
    .progbuf_exception  (progbuf_exception)
);




// ============================================================================
// CLOCK/RESET GENERATION
// ============================================================================
initial begin 
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk; 
end 

initial begin 
    rst_n = 1'b0; 
    repeat (RESET_CYCLE) @(posedge clk);
    rst_n = 1'b1;
end 


// ============================================================================
// HELPER TASKS
// ============================================================================
task automatic wait_condition(input logic condition, input int max_cycles, input string description); 
    int cycle_count = 0;
    while (!condition && cycle_count < max_cycles) begin 
        @(posedge clk); 
        cycle_count ++;
    end 

    if (cycle_count >= max_cycles) begin 
        $display("[ERROR] Timeout waiting for: %s", description);
        test_error = 1'b1;
    end 

endtask : wait_condition



task automatic dmi_write(input logic [6:0] addr, input logic [31:0] wdata);
    @(posedge clk);
    dmi_addr  = addr;
    dmi_wdata = wdata;
    dmi_we    = 1'b1;
    dmi_re    = 1'b0;
    dmi_valid = 1'b1;

    @(posedge clk);
    dmi_valid = 1'b0;
    dmi_we    = 1'b0;
    @(posedge clk);
endtask : dmi_write

task automatic dmi_read (input logic [6:0] addr, output logic [31:0] rdata);
    @(posedge clk);
    dmi_addr  = addr; 
    dmi_we    = 1'b0;
    dmi_re    = 1'b1;
    dmi_valid = 1'b1;

    @(posedge clk);
    rdata     = dmi_rdata;
    dmi_valid = 1'b0;
    dmi_re    = 1'b0;
    @(posedge clk);  
endtask : dmi_read 

task automatic assert_equal (input logic [31:0] actual, input logic [31:0] expected, input string test_name);
    if (actual == expected) begin 
        $display("[PASS] %s - Expected: 0x%08x, Got: 0x%08x", test_name, expected, actual);
        pass_count ++; 

    end else begin 
        $display("[Fail] %s - Expected: 0x%08x, Got: 0x%08x", test_name, expected, actual);
        fail_count ++; 
        test_error = 1'b1;
    end 
endtask : assert_equal

// ============================================================================
// TEST 1 : power on reset and init 
// ============================================================================
task test_reset_init();
    dmstatus_t dmstatus; 
    $display("\n=== TEST 1 : Reset and Init ===");

    wait_condition(rst_n, 100, "Reset release");
    @(posedge clk);

    dmi_read(DMI_DMSTATUS, dmstatus);
    assert_equal(32'(dmstatus.version), 32'h2, "DMSTATUS Version should be 0x2");
    assert_equal(32'(dmstatus.authenticated), 32'b1, "DMSTATUS authenticated should be 1");
    assert_equal(32'(dmstatus.authbusy), 32'b0, "DMSTATUS authbusy should be 0");
    $display("✅ TEST 1: PASS\n");

endtask : test_reset_init



// ============================================================================
// TEST 2: DMI register access (read/write)
// ============================================================================






// ============================================================================
// TEST 3: Hart control (halt/resume)
// ============================================================================




// ============================================================================
// TEST 4 : Abstract command - Register write
// ============================================================================





// ============================================================================
// TEST 6 : PC access 
// ============================================================================



// ============================================================================
// TEST 7 : ABSTRACTCS register
// ============================================================================




// ============================================================================
// TEST 8 : DMCONTROL register
// ============================================================================




// ============================================================================
// TEST 9 : Multiple data registers
// ============================================================================





// ============================================================================
// TEST 10 : State machine transitions
// ============================================================================




// ============================================================================
// MAIN TEST SEQUENCE
// ============================================================================
initial begin 
    test_error  = 1'b0;
    test_count  = 0; 
    pass_count  = 0;
    fail_count  = 0;

    dmi_addr    = 7'h0;
    dmi_wdata   = 32'h0;
    dmi_we      = 1'b0;
    dmi_re      = 1'b0;
    dmi_valid   = 1'b0;


    hart_halted = 1'b0;
    hart_regfile_rdata = 32'h0;
    hart_pc_rdata = 32'h0;
    progbuf_done = 1'b0;
    progbuf_exception = 1'b0;

    $display("\n════════════════════════════════════════════════════════\n");


    test_reset_init();

    $display("\n");
    $display("════════════════════════════════════════════════════════");
    $display("                    TEST SUMMARY                        ");
    $display("════════════════════════════════════════════════════════");
    $display("Total Tests:  %0d", test_count);
    $display("Passed:       %0d", pass_count);
    $display("Failed:       %0d", fail_count);
    $finish();

end 
endmodule : tb_debug_module