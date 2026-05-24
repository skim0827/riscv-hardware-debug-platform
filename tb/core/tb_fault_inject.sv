`timescale 1ns/1ps

module tb_fault_inject;
import riscv_pkg::*;

localparam CLK_HALF = 5;
localparam RUN_CYCLES = 80;

logic        clk, rst_n;
logic        hart_halt_req, hart_resume_req, hart_reset_req;
logic        hart_halted;
logic [4:0]  hart_regfile_addr;
logic [31:0] hart_regfile_wdata;
logic        hart_regfile_we;
logic [31:0] hart_regfile_rdata;
logic [31:0] hart_pc_wdata;
logic        hart_pc_we;
logic [31:0] hart_pc_rdata;
logic [31:0] progbuf_instr;
logic        progbuf_exec;
logic        progbuf_done, progbuf_exception;
logic        imem_corrected, imem_detected;
logic        dmem_corrected, dmem_detected;
logic        tmr_pc_error, tmr_fsm_error, tmr_rf_error, tmr_ir_error;

cpu dut (
    .clk              (clk),
    .rst_n            (rst_n),
    .hart_halt_req    (hart_halt_req),
    .hart_resume_req  (hart_resume_req),
    .hart_reset_req   (hart_reset_req),
    .hart_halted      (hart_halted),
    .hart_regfile_addr (hart_regfile_addr),
    .hart_regfile_wdata(hart_regfile_wdata),
    .hart_regfile_we  (hart_regfile_we),
    .hart_regfile_rdata(hart_regfile_rdata),
    .hart_pc_wdata    (hart_pc_wdata),
    .hart_pc_we       (hart_pc_we),
    .hart_pc_rdata    (hart_pc_rdata),
    .progbuf_instr    (progbuf_instr),
    .progbuf_exec     (progbuf_exec),
    .progbuf_done     (progbuf_done),
    .progbuf_exception(progbuf_exception),
    .imem_corrected   (imem_corrected),
    .imem_detected    (imem_detected),
    .dmem_corrected   (dmem_corrected),
    .dmem_detected    (dmem_detected),
    .tmr_pc_error     (tmr_pc_error),
    .tmr_fsm_error    (tmr_fsm_error),
    .tmr_rf_error     (tmr_rf_error),
    .tmr_ir_error     (tmr_ir_error)
);

initial clk = 0;
always #CLK_HALF clk =~clk;
localparam logic [5:0] CW_POS [32] = '{
    6'd3,  6'd5,  6'd6,  6'd7,  6'd9,  6'd10, 6'd11, 6'd12,
    6'd13, 6'd14, 6'd15, 6'd17, 6'd18, 6'd19, 6'd20, 6'd21,
    6'd22, 6'd23, 6'd24, 6'd25, 6'd26, 6'd27, 6'd28, 6'd29,
    6'd30, 6'd31, 6'd33, 6'd34, 6'd35, 6'd36, 6'd37, 6'd38
};
 
function automatic [6:0] ecc_encode_tb(input logic [31:0] data);
    logic [5:0] h;
    h = 6'b0;
    for (int i = 0; i < 32; i++)
        if (data[i]) h ^= CW_POS[i];
    return {(^data ^ ^h), h};
endfunction


int pass_cnt, fail_cnt;


task automatic do_reset();
    rst_n           = 0;
    hart_halt_req   = 0;
    hart_resume_req = 0;
    hart_reset_req  = 0;
    hart_regfile_we = 0;
    hart_regfile_addr  = 0;
    hart_regfile_wdata = 0;
    hart_pc_we      = 0;
    hart_pc_wdata   = 0;
    progbuf_exec    = 0;
    progbuf_instr   = 0;
    dut.u_IMEM.load_init();
    repeat(4) @(posedge clk);
    rst_n = 1;
endtask

task automatic run_and_halt();
    repeat(RUN_CYCLES) @(posedge clk);
    hart_halt_req = 1;
    @(posedge clk);
    hart_halt_req = 0;
    repeat(4) @(posedge clk);   // settle
endtask

task automatic read_reg(input [4:0] addr, output [31:0] val);
    hart_regfile_addr = addr;
    @(negedge clk);
    val = hart_regfile_rdata;
endtask

task automatic check_reg(
    input [4:0]  reg_num,
    input [31:0] expected,
    input string label
);
    logic [31:0] got;
    read_reg(reg_num, got);
    if (got === expected) begin
        $display("  ✅ PASS  %-20s x%0d = 0x%08X", label, reg_num, got);
        pass_cnt++;
    end else begin
        $display("  ❌ FAIL  %-20s x%0d = 0x%08X  (expected 0x%08X)", label, reg_num, got, expected);
        fail_cnt++;
    end
endtask

task automatic check_flag(input logic flag, input string label);
    if (flag) begin
        $display("  ✅ PASS  %s asserted", label);
        pass_cnt++;
    end else begin
        $display("  ❌ FAIL  %s NOT asserted", label);
        fail_cnt++;
    end
endtask

task automatic print_telemetry();
    $display("  [TEL] imem_corrected_seen=%b  imem_detected_seen=%b  dmem_corrected_seen=%b  dmem_detected_seen=%b",
             imem_corrected_seen, imem_detected_seen, dmem_corrected_seen, dmem_detected_seen);
    $display("  [TEL] tmr_pc_seen=%b  tmr_fsm_seen=%b  tmr_rf_seen=%b  tmr_ir_seen=%b",
             tmr_pc_seen, tmr_fsm_seen, tmr_rf_seen, tmr_ir_seen);
endtask

logic imem_corrected_seen, imem_detected_seen;
logic dmem_corrected_seen, dmem_detected_seen;
logic tmr_pc_seen, tmr_fsm_seen, tmr_rf_seen, tmr_ir_seen;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        imem_corrected_seen <= 0; imem_detected_seen <= 0;
        dmem_corrected_seen <= 0; dmem_detected_seen <= 0;
        tmr_pc_seen <= 0; tmr_fsm_seen <= 0; tmr_rf_seen <= 0; tmr_ir_seen <= 0;
    end else begin
        if (imem_corrected) imem_corrected_seen <= 1;
        if (imem_detected)  imem_detected_seen  <= 1;
        if (dmem_corrected) dmem_corrected_seen <= 1;
        if (dmem_detected)  dmem_detected_seen  <= 1;
        if (tmr_pc_error)   tmr_pc_seen  <= 1;
        if (tmr_fsm_error)  tmr_fsm_seen <= 1;
        if (tmr_rf_error)   tmr_rf_seen  <= 1;
        if (tmr_ir_error)   tmr_ir_seen  <= 1;
    end
end

initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    $dumpfile("tb_fault_inject.vcd");
    $dumpvars(0, tb_fault_inject);

    $display("\n======== TEST 1 : Clean execution ========");
    do_reset();
    run_and_halt();
    check_reg(1, 32'd5, "clean x1");
    check_reg(2, 32'd3, "clean x2");
    check_reg(3, 32'd8, "clean x3");
    check_reg(4, 32'd8, "clean x4 (lw)");
    print_telemetry();

    $display("\n======== TEST 2 : IMEM 1-bit flip (ECC correction) ========");
    do_reset();
    // inject after load: flip data bit 0 of word 0
    dut.u_IMEM.mem[0] = dut.u_IMEM.mem[0] ^ 39'h000000001;
    @(negedge clk);
    run_and_halt();
    check_reg(1, 32'd5, "1-bit corrected x1");
    check_reg(3, 32'd8, "1-bit corrected x3");
    check_flag(imem_corrected_seen, "imem_corrected");
    print_telemetry();

    $display("\n======== TEST 3 : IMEM 2-bit flip (ECC detection) ========");
    do_reset();
    dut.u_IMEM.mem[0] = dut.u_IMEM.mem[0] ^ 39'h000000003;
    @(negedge clk);
    run_and_halt();
    check_flag(imem_detected_seen, "imem_detected");
    $display("  INFO  x1=0x%08X (corrupted data — detection only)",
             dut.u_regfile.u_rf_0.registers[1]);
    print_telemetry();


    $display("\n======== TEST 4 : DMEM 1-bit flip (ECC correction on load) ========");
    // halt core → inject/load progbuf → pulse exec → wait done → check result → resume.
    do_reset();
    run_and_halt();   // clean run — sw writes mem[0]=8 with correct ECC

    dut.u_DMEM.mem[0] = dut.u_DMEM.mem[0] ^ 39'h000000008;
    // $display("DMEM data = 0x%08X", dut.u_DMEM.mem[0][31:0]);
    @(negedge clk);

    progbuf_instr = 32'h00002283;   // lw x5, 0(x0)
    progbuf_exec  = 1;
    @(posedge clk); // FSM safely sees exec = 1
    @(negedge clk); // SystemVerilog does not guarantee that the FSM samples before the testbench assignmen
    progbuf_exec  = 0;
    

    wait (progbuf_done);
    repeat(2) @(posedge clk);

    check_reg(5, 32'd8, "dmem 1-bit corrected x5");
    check_flag(dmem_corrected_seen, "dmem_corrected");

    hart_resume_req = 1;
    @(posedge clk);
    hart_resume_req = 0;
    print_telemetry();


    $display("\n======== TEST 5 : TMR PC — one replica corrupted ========");
    do_reset();

    repeat(10) @(posedge clk);
    dut.u_pc.pc_0 = 32'hDEADBEEF;
    @(posedge clk);         // hold for 1 cycle so tmr_error fires
    run_and_halt();
    check_reg(1, 32'd5, "PC-TMR x1");
    check_reg(3, 32'd8, "PC-TMR x3");
    check_flag(tmr_pc_seen, "tmr_pc_error");
    print_telemetry();

    $display("\n======== TEST 6 : TMR regfile — one replica corrupted ========");
    do_reset();
    run_and_halt();
    // Corrupt replica 0 of x3
    dut.u_regfile.u_rf_0.registers[3] = 32'hFFFFFFFF;
    @(negedge clk);
    // The voted output should still be 8 (majority of 0xFFFFFFFF, 8, 8)
    check_reg(3, 32'd8, "RF-TMR x3 voted");
    check_flag(tmr_rf_seen, "tmr_rf_error");
    print_telemetry();

    $display("\n======== TEST 7 : TMR FSM — one replica state corrupted ========");
    do_reset();
    repeat(5) @(posedge clk);
    // Force fsm_0 into a garbage state (4'hF = undefined state → S_FETCH default)
    dut.u_control.u_fsm.u_fsm_0.state = state_t'(4'hF);
    @(posedge clk);
    run_and_halt();
    check_reg(1, 32'd5, "FSM-TMR x1");
    check_reg(3, 32'd8, "FSM-TMR x3");
    check_flag(tmr_fsm_seen, "tmr_fsm_error");
    print_telemetry();

    $display("\n======== RESULTS : %0d passed, %0d failed ========\n",
             pass_cnt, fail_cnt);
    #50;
    $finish;
end 

initial begin
    #500000;
    $display("WATCHDOG: simulation exceeded 500us — force quit");
    $finish;
end
endmodule
