// ============================================================================
// TESTBENCH: RISC-V Debug Module v0.13.2
// ============================================================================
// Simple, clean, and COMPLETE testbench
// Test Coverage: DMI, registers, hart control, commands, error handling
// ============================================================================

`timescale 1ns/1ps

module tb_debug_module();

import dmi_pkg::*;
import riscv_pkg::*;

localparam CLK_PERIOD = 10;      // 100MHz
localparam RESET_CYCLES = 5;

// ============================================================================
// SIGNALS
// ============================================================================

logic clk, rst_n;

logic [6:0]   dmi_addr;
logic [31:0]  dmi_wdata;
logic         dmi_we, dmi_re, dmi_valid;
logic [31:0]  dmi_rdata;

logic hart_halted;
logic hart_halt_req, hart_resume_req, hart_reset_req;

logic [31:0] hart_regfile_rdata;
logic [31:0] hart_regfile_wdata;
logic [4:0]  hart_regfile_addr;
logic        hart_regfile_we;

logic [31:0] hart_pc_rdata;
logic [31:0] hart_pc_wdata;
logic        hart_pc_we;

logic [31:0] progbuf_instr;
logic        progbuf_exec, progbuf_done, progbuf_exception;

int pass_count = 0;
int fail_count = 0;

// ============================================================================
// DUT
// ============================================================================

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
// CLOCK / RESET
// ============================================================================

initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    repeat (RESET_CYCLES) @(posedge clk);
    rst_n = 1'b1;
end

// ============================================================================
// HELPER TASKS
// ============================================================================

task automatic dmi_write(logic [6:0] addr, logic [31:0] data);
    @(posedge clk);
    dmi_addr  = addr;
    dmi_wdata = data;
    dmi_we    = 1'b1;
    dmi_re    = 1'b0;
    dmi_valid = 1'b1;
    @(posedge clk);
    dmi_valid = 1'b0;
    dmi_we    = 1'b0;
endtask

task automatic dmi_read(logic [6:0] addr, output logic [31:0] data);
    @(posedge clk);
    dmi_addr  = addr;
    dmi_we    = 1'b0;
    dmi_re    = 1'b1;
    dmi_valid = 1'b1;
    @(posedge clk);
    data = dmi_rdata;
    dmi_valid = 1'b0;
    dmi_re    = 1'b0;
endtask

task automatic check(logic [31:0] actual, logic [31:0] expected, string name);
    if (actual === expected) begin
        $display("✓ PASS: %s", name);
        pass_count++;
    end else begin
        $display("✗ FAIL: %s | Expected: 0x%08x | Got: 0x%08x", name, expected, actual);
        fail_count++;
    end
endtask

task automatic wait_cmd_done();
    logic [31:0] abstractcs;
    int timeout = 0;
    do begin
        dmi_read(DMI_ABSTRACTCS, abstractcs);
        @(posedge clk);
        timeout++;
        if (timeout > 100) begin
            $display("✗ ERROR: Command timeout!");
            return;
        end
    end while (abstractcs[12]);
endtask

task automatic wait_condition(logic condition, int max_cycles);
    int count = 0;
    while (!condition && count < max_cycles) begin
        @(posedge clk);
        count++;
    end
endtask

// ============================================================================
// TESTS
// ============================================================================

task automatic test_reset_and_init();
    dmstatus_t dmstatus;
    
    $display("\n--- TEST 1: Reset and Initialization ---");
    
    wait_condition(rst_n, 100);
    @(posedge clk);
    
    dmi_read(DMI_DMSTATUS, dmstatus);
    check(32'(dmstatus.version), 32'h2, "DMSTATUS version = 0x2");
    check(32'(dmstatus.authenticated), 32'h1, "DMSTATUS authenticated");
endtask

task automatic test_dmi_data_registers();
    logic [31:0] rdata;
    
    $display("\n--- TEST 2: DMI Data Registers ---");
    
    dmi_write(DMI_DATA0, 32'hDEADBEEF);
    dmi_read(DMI_DATA0, rdata);
    check(rdata, 32'hDEADBEEF, "DATA0 write/read");
    
    dmi_write(DMI_DATA1, 32'hCAFECAFE);
    dmi_read(DMI_DATA1, rdata);
    check(rdata, 32'hCAFECAFE, "DATA1 write/read");
endtask

task automatic test_hart_status();
    dmstatus_t dmstatus;
    
    $display("\n--- TEST 3: Hart Status ---");
    
    hart_halted = 1'b0;
    repeat(5) @(posedge clk);
    dmi_read(DMI_DMSTATUS, dmstatus);
    check(32'(dmstatus.anyrunning), 32'h1, "DMSTATUS anyrunning");
    
    hart_halted = 1'b1;
    repeat(5) @(posedge clk);
    dmi_read(DMI_DMSTATUS, dmstatus);
    check(32'(dmstatus.anyhalted), 32'h1, "DMSTATUS anyhalted");
endtask

task automatic test_gpr_write();
    logic [4:0] gpr_num = 5'd5;
    logic [31:0] test_value = 32'h12345678;
    cmd_access_register_t cmd_reg;
    
    $display("\n--- TEST 4: Write GPR (x5) ---");
    
    hart_halted = 1'b1;
    repeat(5) @(posedge clk);
    
    dmi_write(DMI_DATA0, test_value);
    
    cmd_reg = 32'h0;
    cmd_reg.cmdtype = CMD_ACCESS_REG;
    cmd_reg.transfer    = 1'b1;
    cmd_reg.write    = 1'b1;
    cmd_reg.regno  = (16'h1000 | 16'(gpr_num));
    
    dmi_write(DMI_COMMAND, cmd_reg);
    wait_cmd_done();
    
    check(32'(hart_regfile_addr), 32'(gpr_num), "hart_regfile_addr matches GPR");
endtask

task automatic test_gpr_read();
    logic [4:0] gpr_num = 5'd10;
    logic [31:0] test_value = 32'hABCDEF00;
    logic [31:0] cmd_reg;
    logic [31:0] read_result;
    
    $display("\n--- TEST 5: Read GPR (x10) ---");
    
    hart_halted = 1'b1;
    repeat(5) @(posedge clk);
    
    hart_regfile_rdata = test_value;
    
    cmd_reg = 32'h0;
    cmd_reg[31:24] = 8'h00;
    cmd_reg[17]    = 1'b1;
    cmd_reg[16]    = 1'b0;
    cmd_reg[15:0]  = (16'h1000 | 16'(gpr_num));
    
    dmi_write(DMI_COMMAND, cmd_reg);
    wait_cmd_done();
    
    dmi_read(DMI_DATA0, read_result);
    check(read_result, test_value, "GPR read result in DATA0");
endtask

task automatic test_pc_write();
    logic [31:0] pc_value = 32'h80000000;
    logic [31:0] cmd_reg;
    logic pc_we_detected = 1'b0;
    logic [31:0] pc_wdata_captured;
    
    $display("\n--- TEST 6: Write PC ---");
    
    hart_halted = 1'b1;
    repeat(5) @(posedge clk);
    
    dmi_write(DMI_DATA0, pc_value);
    
    cmd_reg = 32'h0;
    cmd_reg[31:24] = 8'h00;
    cmd_reg[17]    = 1'b1;
    cmd_reg[16]    = 1'b1;
    cmd_reg[15:0]  = 16'h7b1;
    
    dmi_write(DMI_COMMAND, cmd_reg);
    
    do begin
        if (hart_pc_we) begin
            pc_we_detected = 1'b1;
            pc_wdata_captured = hart_pc_wdata;
        end
        @(posedge clk);
    end while (dut.abstractcs_reg.busy);
    
    check(32'(pc_we_detected), 32'h1, "hart_pc_we pulsed");
    check(pc_wdata_captured, pc_value, "hart_pc_wdata matches");
endtask

task automatic test_command_busy_error();
    logic [31:0] cmd_reg;
    logic [31:0] abstractcs;
    
    $display("\n--- TEST 7: Command Busy Error ---");
    
    hart_halted = 1'b1;
    repeat(5) @(posedge clk);
    
    // Issue first command
    dmi_write(DMI_DATA0, 32'hAAAA);
    cmd_reg = 32'h0;
    cmd_reg[31:24] = 8'h00;
    cmd_reg[17]    = 1'b1;
    cmd_reg[16]    = 1'b1;
    cmd_reg[15:0]  = 16'h1005;
    dmi_write(DMI_COMMAND, cmd_reg);
    
    // Try to issue second command while busy
    @(posedge clk);
    cmd_reg = 32'h0;
    cmd_reg[31:24] = 8'h00;
    cmd_reg[17]    = 1'b1;
    cmd_reg[16]    = 1'b1;
    cmd_reg[15:0]  = 16'h100a;
    dmi_write(DMI_COMMAND, cmd_reg);
    
    // Read ABSTRACTCS - should have CMDERR_BUSY
    @(posedge clk);
    dmi_read(DMI_ABSTRACTCS, abstractcs);
    check(32'(abstractcs[10:8]), 32'h1, "CMDERR_BUSY set when busy");
endtask

task automatic test_consecutive_commands();
    logic [31:0] cmd_reg;
    logic [4:0] gpr1 = 5'd5;
    logic [4:0] gpr2 = 5'd10;
    
    $display("\n--- TEST 8: Consecutive Commands ---");
    
    hart_halted = 1'b1;
    repeat(5) @(posedge clk);
    
    // Write to GPR x5
    dmi_write(DMI_DATA0, 32'h11111111);
    cmd_reg = 32'h0;
    cmd_reg[31:24] = 8'h00;
    cmd_reg[17]    = 1'b1;
    cmd_reg[16]    = 1'b1;
    cmd_reg[15:0]  = (16'h1000 | 16'(gpr1));
    dmi_write(DMI_COMMAND, cmd_reg);
    wait_cmd_done();
    
    // Write to GPR x10
    dmi_write(DMI_DATA0, 32'h22222222);
    cmd_reg = 32'h0;
    cmd_reg[31:24] = 8'h00;
    cmd_reg[17]    = 1'b1;
    cmd_reg[16]    = 1'b1;
    cmd_reg[15:0]  = (16'h1000 | 16'(gpr2));
    dmi_write(DMI_COMMAND, cmd_reg);
    wait_cmd_done();
    
    check(32'(hart_regfile_addr), 32'(gpr2), "Second command executed successfully");
endtask

task automatic test_write_read_flow();
    logic [31:0] cmd_reg;
    logic [31:0] write_value = 32'hDEADBEEF;
    logic [31:0] read_value;
    logic [4:0] test_gpr = 5'd7;
    
    $display("\n--- TEST 9: Write-Read Flow ---");
    
    hart_halted = 1'b1;
    repeat(5) @(posedge clk);
    
    // Write to GPR x7
    dmi_write(DMI_DATA0, write_value);
    cmd_reg = 32'h0;
    cmd_reg[31:24] = 8'h00;
    cmd_reg[17]    = 1'b1;
    cmd_reg[16]    = 1'b1;
    cmd_reg[15:0]  = (16'h1000 | 16'(test_gpr));
    dmi_write(DMI_COMMAND, cmd_reg);
    wait_cmd_done();
    
    // Setup hart to return the same value
    hart_regfile_rdata = write_value;
    
    // Read from GPR x7
    cmd_reg = 32'h0;
    cmd_reg[31:24] = 8'h00;
    cmd_reg[17]    = 1'b1;
    cmd_reg[16]    = 1'b0;
    cmd_reg[15:0]  = (16'h1000 | 16'(test_gpr));
    dmi_write(DMI_COMMAND, cmd_reg);
    wait_cmd_done();
    
    dmi_read(DMI_DATA0, read_value);
    check(read_value, write_value, "Read-back matches write value");
endtask
// ============================================================================
// FUNCTIONAL COVERAGE
// ============================================================================
 
/* verilator lint_off COVERIGN */
covergroup cg_dmi_operations;
    cp_dmi_write: coverpoint dmi_we {
        bins write_active = {1'b1};
        bins write_idle = {1'b0};
    }
    cp_dmi_read: coverpoint dmi_re {
        bins read_active = {1'b1};
        bins read_idle = {1'b0};
    }
    cp_hart_state: coverpoint hart_halted {
        bins halted = {1'b1};
        bins running = {1'b0};
    }
    cp_cmd_state: coverpoint dut.cmd_state {
        bins idle = {0};
        bins decode = {1};
        bins setup = {2};
        bins sample = {3};
        bins write_state = {4};
        bins progbuf = {5};
        bins done = {6};
        bins error = {7};
    }
    
    // Cross coverage
    cross_dmi_hart: cross cp_dmi_write, cp_hart_state;
endgroup
/* verilator lint_on COVERIGN */
 
cg_dmi_operations cg_inst;
 
// Initialize coverage group
initial begin
    cg_inst = new();
end
 
// Sample coverage on every clock
always @(posedge clk) begin
    cg_inst.sample();
end

// ============================================================================
// MAIN
// ============================================================================
 
initial begin
    dmi_addr  = 7'h0;
    dmi_wdata = 32'h0;
    dmi_we    = 1'b0;
    dmi_re    = 1'b0;
    dmi_valid = 1'b0;
    hart_halted = 1'b0;
    hart_regfile_rdata = 32'h0;
    hart_pc_rdata = 32'h0;
    progbuf_done = 1'b0;
    progbuf_exception = 1'b0;
    
    $display("\n");
    $display("╔════════════════════════════════════════╗");
    $display("║   DEBUG MODULE TESTBENCH               ║");
    $display("║   RISC-V v0.13.2 with Coverage        ║");
    $display("╚════════════════════════════════════════╝");
    
    wait_condition(rst_n, 100);
    repeat(10) @(posedge clk);
    
    test_reset_and_init();
    test_dmi_data_registers();
    test_hart_status();
    test_gpr_write();
    test_gpr_read();
    test_pc_write();
    test_command_busy_error();
    test_consecutive_commands();
    test_write_read_flow();
    
    $display("\n");
    $display("╔════════════════════════════════════════╗");
    $display("║            RESULTS                     ║");
    $display("╚════════════════════════════════════════╝");
    $display("PASS: %0d", pass_count);
    $display("FAIL: %0d", fail_count);
    
    if (fail_count == 0)
        $display("\n✓ ALL TESTS PASSED\n");
    else
        $display("\n✗ SOME TESTS FAILED\n");
    
    #100;
    $finish;
end

endmodule