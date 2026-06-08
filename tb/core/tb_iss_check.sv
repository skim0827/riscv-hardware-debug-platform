`timescale 1ns/1ps
// ISS ↔ RTL cross-check testbench.
// ISS : no UART, no DMEM, dumps a PC trace

module tb_iss_check;
import riscv_pkg::*;
import axi4_lite_pkg::*;

localparam CLK_HALF   = 5;
localparam MAX_INSTRS = 5;    // crosscheck.hex has exactly 5 instructions

logic        clk, rst_n;
logic        hart_halted;
logic [31:0] progbuf_instr;
logic        progbuf_exec, progbuf_done, progbuf_exception;
logic        tmr_pc_error, tmr_fsm_error, tmr_rf_error, tmr_ir_error;


logic [31:0] imem_araddr;
logic        imem_arvalid, imem_arready;
logic [31:0] imem_rdata;
logic [1:0]  imem_rresp;
logic        imem_rvalid, imem_rready;


logic [31:0] m_awaddr; logic m_awvalid; logic m_awready;
logic [31:0] m_wdata;  logic [3:0] m_wstrb; logic m_wvalid; logic m_wready;
logic [1:0]  m_bresp;  logic m_bvalid; logic m_bready;
logic [31:0] m_araddr; logic m_arvalid; logic m_arready;
logic [31:0] m_rdata;  logic [1:0] m_rresp; logic m_rvalid; logic m_rready;

// tie off unused debug/halt ports
logic [4:0]  hart_regfile_addr  = '0;
logic [31:0] hart_regfile_wdata = '0;
logic        hart_regfile_we    = '0;
logic [31:0] hart_regfile_rdata;
logic [31:0] hart_pc_wdata = '0;
logic        hart_pc_we    = '0;
logic [31:0] hart_pc_rdata;

cpu dut (
    .clk(clk), .rst_n(rst_n),
    .hart_halt_req(1'b0), .hart_resume_req(1'b0), .hart_reset_req(1'b0),
    .hart_halted(hart_halted),
    .hart_regfile_addr(hart_regfile_addr), .hart_regfile_wdata(hart_regfile_wdata),
    .hart_regfile_we(hart_regfile_we),     .hart_regfile_rdata(hart_regfile_rdata),
    .hart_pc_wdata(hart_pc_wdata), .hart_pc_we(hart_pc_we), .hart_pc_rdata(hart_pc_rdata),
    .progbuf_instr(32'b0), .progbuf_exec(1'b0),
    .progbuf_done(progbuf_done), .progbuf_exception(progbuf_exception),
    .tmr_pc_error(tmr_pc_error), .tmr_fsm_error(tmr_fsm_error),
    .tmr_rf_error(tmr_rf_error), .tmr_ir_error(tmr_ir_error),
    .imem_araddr(imem_araddr),   .imem_arvalid(imem_arvalid), .imem_arready(imem_arready),
    .imem_rdata(imem_rdata),     .imem_rresp(imem_rresp),
    .imem_rvalid(imem_rvalid),   .imem_rready(imem_rready),
    .m_awaddr(m_awaddr), .m_awvalid(m_awvalid), .m_awready(m_awready),
    .m_wdata(m_wdata),   .m_wstrb(m_wstrb),
    .m_wvalid(m_wvalid), .m_wready(m_wready),
    .m_bresp(m_bresp),   .m_bvalid(m_bvalid),  .m_bready(m_bready),
    .m_araddr(m_araddr), .m_arvalid(m_arvalid), .m_arready(m_arready),
    .m_rdata(m_rdata),   .m_rresp(m_rresp),
    .m_rvalid(m_rvalid), .m_rready(m_rready)
);

// IMEM loaded with crosscheck program via init task
axi4_lite_mem_slave #(.WORDS(128), .MEM_INIT(""), .IS_DMEM(0)) u_imem (
    .clk(clk), .rst_n(rst_n),
    .s_awaddr(32'b0), .s_awvalid(1'b0), .s_awready(),
    .s_wdata(32'b0),  .s_wstrb(4'b0),
    .s_wvalid(1'b0),  .s_wready(),
    .s_bresp(),       .s_bvalid(),      .s_bready(1'b1),
    .s_araddr(imem_araddr), .s_arvalid(imem_arvalid), .s_arready(imem_arready),
    .s_rdata(imem_rdata),   .s_rresp(imem_rresp),
    .s_rvalid(imem_rvalid), .s_rready(imem_rready),
    .corrected(), .detected()
);

// DMEM idle (program has no memory accesses)
axi4_lite_mem_slave #(.WORDS(128), .MEM_INIT(""), .IS_DMEM(1)) u_dmem (
    .clk(clk), .rst_n(rst_n),
    .s_awaddr(m_awaddr), .s_awvalid(m_awvalid), .s_awready(m_awready),
    .s_wdata(m_wdata),   .s_wstrb(m_wstrb),
    .s_wvalid(m_wvalid), .s_wready(m_wready),
    .s_bresp(m_bresp),   .s_bvalid(m_bvalid),  .s_bready(m_bready),
    .s_araddr(m_araddr), .s_arvalid(m_arvalid), .s_arready(m_arready),
    .s_rdata(m_rdata),   .s_rresp(m_rresp),
    .s_rvalid(m_rvalid), .s_rready(m_rready),
    .corrected(), .detected()
);

initial clk = 0;
always #CLK_HALF clk = ~clk;

// ECC encoder (same polynomial as BRAM stubs)
localparam logic [5:0] CW_POS [32] = '{
    6'd3,  6'd5,  6'd6,  6'd7,  6'd9,  6'd10, 6'd11, 6'd12,
    6'd13, 6'd14, 6'd15, 6'd17, 6'd18, 6'd19, 6'd20, 6'd21,
    6'd22, 6'd23, 6'd24, 6'd25, 6'd26, 6'd27, 6'd28, 6'd29,
    6'd30, 6'd31, 6'd33, 6'd34, 6'd35, 6'd36, 6'd37, 6'd38
};
function automatic [6:0] ecc_encode(input logic [31:0] d);
    logic [5:0] h = 6'b0;
    for (int i = 0; i < 32; i++) if (d[i]) h ^= CW_POS[i];
    return {(^d ^ ^h), h};
endfunction

task automatic load_prog();
    logic [31:0] prog[0:4] = '{
        32'h00500093,  // addi x1, x0, 5
        32'h00300113,  // addi x2, x0, 3
        32'h002081b3,  // add  x3, x1, x2
        32'h00018213,  // addi x4, x3, 0
        32'h0000006f   // j    .
    };
    for (int i = 0; i < 128; i++)
        u_imem.u_mem.gen_bram.u_bram.mem[i] = 39'b0;
    for (int i = 0; i < 5; i++)
        u_imem.u_mem.gen_bram.u_bram.mem[i] = {ecc_encode(prog[i]), prog[i]};
endtask

// (PC | instruction word)
logic [31:0] fetch_pc_lat;
always_ff @(posedge clk)
    if (imem_arvalid && imem_arready)
        fetch_pc_lat <= imem_araddr;

int fetch_cnt = 0;

always @(posedge clk) begin
    if (imem_rvalid && imem_rready) begin
        $display("RTL PC=%08X | %08X", fetch_pc_lat, imem_rdata);
        fetch_cnt++;
        if (fetch_cnt >= MAX_INSTRS) begin
            $display("[tb_iss_check] Reached MAX_INSTRS=%0d, finishing.", MAX_INSTRS);
            $finish;
        end
    end
end

initial begin
    rst_n = 0;
    load_prog();
    repeat(4) @(posedge clk);
    rst_n = 1;
end

initial begin
    #200000;
    $display("WATCHDOG timeout");
    $finish;
end

endmodule
