`timescale 1ns/1ps
// IMEM is direct; data access goes through the AXI4-Lite crossbar.

module soc_top (
    input  logic clk,
    input logic rst_btn, // active HIGH from button

    // JTAG debug port
    // input  logic tck,
    // input  logic tms,
    // input  logic tdi,
    // output logic tdo,


    output logic uart_tx,

    // Fault telemetry outputs.
    output logic imem_corrected_o,
    output logic imem_detected_o,
    output logic dmem_corrected_o,
    output logic dmem_detected_o,
    output logic tmr_pc_error_o,
    output logic tmr_fsm_error_o,
    output logic tmr_rf_error_o,
    output logic tmr_ir_error_o,

    // Pending IRQ outputs.
    output logic timer_irq_o,
    output logic health_irq_o,
    output logic dma_irq_o
);

import dmi_pkg::*;
import riscv_pkg::*;
import axi4_lite_pkg::*;

// JTAG pins are tied off for this build.

logic tck, tms, tdi, tdo;
assign tck = 1'b0;
assign tms = 1'b1; 
assign tdi = 1'b0;

// arty A7
logic rst_n;
assign rst_n = ~rst_btn;

// TAP control signals (tck domain)
logic capture_dr, shift_dr, update_dr;
logic capture_ir, shift_ir, update_ir;

// DMI bus: tck domain.
logic [6:0]  tck_dmi_addr;
logic [31:0] tck_dmi_wdata;
logic        tck_dmi_we;
logic        tck_dmi_re;
logic [31:0] tck_dmi_rdata;

// DMI bus: clk domain.
logic [6:0]  clk_dmi_addr;
logic [31:0] clk_dmi_wdata;
logic        clk_dmi_we;
logic        clk_dmi_re;
logic        clk_dmi_valid;
logic [31:0] clk_dmi_rdata;

// DTMCS feedback (tck domain)
logic        dtmcs_dmihardreset;
logic        dtmcs_dmireset;
logic [2:0]  dtmcs_idle;
logic [1:0]  dtmcs_dmistat;
logic [5:0]  dtmcs_abits;

assign dtmcs_idle    = 3'b001;
assign dtmcs_dmistat = 2'b00;
assign dtmcs_abits   = 6'd7;

logic _unused_dtmcs_reset;
assign _unused_dtmcs_reset = dtmcs_dmihardreset | dtmcs_dmireset;

// Hart interface (clk domain)
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

// Program buffer interface (clk domain)
logic [31:0] progbuf_instr;
logic        progbuf_exec;
logic        progbuf_done;
logic        progbuf_exception;


// Fault telemetry wires
logic imem_corrected, imem_detected;  // from IMEM slave
logic dmem_corrected, dmem_detected;  // from DMEM slave
logic tmr_pc_error, tmr_fsm_error, tmr_rf_error, tmr_ir_error; // from CPU

assign imem_corrected_o = imem_corrected;
assign imem_detected_o  = imem_detected;
assign dmem_corrected_o = dmem_corrected;
assign dmem_detected_o  = dmem_detected;
assign tmr_pc_error_o   = tmr_pc_error;
assign tmr_fsm_error_o  = tmr_fsm_error;
assign tmr_rf_error_o   = tmr_rf_error;
assign tmr_ir_error_o   = tmr_ir_error;

// Watchdog resets the CPU without resetting debug logic.
logic wdt_reset;
logic cpu_rst_n;

assign cpu_rst_n = rst_n & ~wdt_reset;

// IRQ wires
logic timer_irq;
logic health_irq;
logic dma_irq;

assign timer_irq_o = timer_irq;
assign health_irq_o = health_irq;
assign dma_irq_o   = dma_irq;

// CPU AXI4-Lite master ports.

// Instruction fetch (IMEM direct)
logic [31:0] imem_araddr;
logic        imem_arvalid;
logic        imem_arready;
logic [31:0] imem_rdata;
logic [1:0]  imem_rresp;
logic        imem_rvalid;
logic        imem_rready;
logic        imem_awready_unused;
logic        imem_wready_unused;
logic [1:0]  imem_bresp_unused;
logic        imem_bvalid_unused;

// Data bus — CPU (M0)
logic [31:0] cpu_m_awaddr;  logic cpu_m_awvalid; logic cpu_m_awready;
logic [31:0] cpu_m_wdata;   logic [3:0] cpu_m_wstrb; logic cpu_m_wvalid; logic cpu_m_wready;
logic [1:0]  cpu_m_bresp;   logic cpu_m_bvalid;  logic cpu_m_bready;
logic [31:0] cpu_m_araddr;  logic cpu_m_arvalid; logic cpu_m_arready;
logic [31:0] cpu_m_rdata;   logic [1:0] cpu_m_rresp; logic cpu_m_rvalid; logic cpu_m_rready;

// Data bus — DMA (M1)
logic [31:0] dma_m_awaddr;  logic dma_m_awvalid; logic dma_m_awready;
logic [31:0] dma_m_wdata;   logic [3:0] dma_m_wstrb; logic dma_m_wvalid; logic dma_m_wready;
logic [1:0]  dma_m_bresp;   logic dma_m_bvalid;  logic dma_m_bready;
logic [31:0] dma_m_araddr;  logic dma_m_arvalid; logic dma_m_arready;
logic [31:0] dma_m_rdata;   logic [1:0] dma_m_rresp; logic dma_m_rvalid; logic dma_m_rready;

// AXI4-Lite crossbar slave port arrays
logic [31:0] s_awaddr  [NUM_SLAVES];
logic        s_awvalid [NUM_SLAVES];
logic        s_awready [NUM_SLAVES];
logic [31:0] s_wdata   [NUM_SLAVES];
logic [3:0]  s_wstrb   [NUM_SLAVES];
logic        s_wvalid  [NUM_SLAVES];
logic        s_wready  [NUM_SLAVES];
logic [1:0]  s_bresp   [NUM_SLAVES];
logic        s_bvalid  [NUM_SLAVES];
logic        s_bready  [NUM_SLAVES];
logic [31:0] s_araddr  [NUM_SLAVES];
logic        s_arvalid [NUM_SLAVES];
logic        s_arready [NUM_SLAVES];
logic [31:0] s_rdata   [NUM_SLAVES];
logic [1:0]  s_rresp   [NUM_SLAVES];
logic        s_rvalid  [NUM_SLAVES];
logic        s_rready  [NUM_SLAVES];



tap_fsm tap_controller (
    .tck       (tck),
    .tms       (tms),
    .capture_ir(capture_ir),
    .shift_ir  (shift_ir),
    .update_ir (update_ir),
    .capture_dr(capture_dr),
    .shift_dr  (shift_dr),
    .update_dr (update_dr)
);

dtm_top #(
    .WIDTH      (32),
    .DTMCS_WIDTH(32),
    .DMI_WIDTH  (41),
    .IDCODE_WIDTH(32)
) u_dtm (
    .tck               (tck),
    .tdi               (tdi),
    .tdo               (tdo),
    .capture_ir        (capture_ir),
    .shift_ir          (shift_ir),
    .update_ir         (update_ir),
    .capture_dr        (capture_dr),
    .shift_dr          (shift_dr),
    .update_dr         (update_dr),
    .dmi_addr          (tck_dmi_addr),
    .dmi_wdata         (tck_dmi_wdata),
    .dmi_we            (tck_dmi_we),
    .dmi_re            (tck_dmi_re),
    .dmi_rdata         (tck_dmi_rdata),
    .dtmcs_dmihardreset(dtmcs_dmihardreset),
    .dtmcs_dmireset    (dtmcs_dmireset),
    .dtmcs_idle        (dtmcs_idle),
    .dtmcs_dmistat     (dtmcs_dmistat),
    .dtmcs_abits       (dtmcs_abits)
);

// DMI CDC bridge.
dmi_cdc_bridge u_cdc (
    .tck          (tck),
    .clk          (clk),
    .rst_n        (rst_n),
    .tck_dmi_addr (tck_dmi_addr),
    .tck_dmi_wdata(tck_dmi_wdata),
    .tck_dmi_we   (tck_dmi_we),
    .tck_dmi_re   (tck_dmi_re),
    .tck_dmi_rdata(tck_dmi_rdata),
    .clk_dmi_addr (clk_dmi_addr),
    .clk_dmi_wdata(clk_dmi_wdata),
    .clk_dmi_we   (clk_dmi_we),
    .clk_dmi_re   (clk_dmi_re),
    .clk_dmi_valid(clk_dmi_valid),
    .clk_dmi_rdata(clk_dmi_rdata)
);

// Debug module (clk domain)
debug_module u_dm (
    .clk               (clk),
    .rst_n             (rst_n),
    .dmi_addr          (clk_dmi_addr),
    .dmi_wdata         (clk_dmi_wdata),
    .dmi_we            (clk_dmi_we),
    .dmi_re            (clk_dmi_re),
    .dmi_rdata         (clk_dmi_rdata),
    .dmi_valid         (clk_dmi_valid),
    .hart_halted       (hart_halted),
    .hart_halt_req     (hart_halt_req),
    .hart_resume_req   (hart_resume_req),
    .hart_reset_req    (hart_reset_req),
    .hart_regfile_rdata(hart_regfile_rdata),
    .hart_regfile_wdata(hart_regfile_wdata),
    .hart_regfile_addr (hart_regfile_addr),
    .hart_regfile_we   (hart_regfile_we),
    .hart_pc_rdata     (hart_pc_rdata),
    .hart_pc_wdata     (hart_pc_wdata),
    .hart_pc_we        (hart_pc_we),
    .progbuf_instr     (progbuf_instr),
    .progbuf_exec      (progbuf_exec),
    .progbuf_done      (progbuf_done),
    .progbuf_exception (progbuf_exception)
);

// CPU core. Watchdog reset uses cpu_rst_n.
cpu u_cpu (
    .clk               (clk),
    .rst_n             (cpu_rst_n), 

    // Hart interface
    .hart_halt_req     (hart_halt_req),
    .hart_resume_req   (hart_resume_req),
    .hart_reset_req    (hart_reset_req),
    .hart_halted       (hart_halted),
    .hart_regfile_addr (hart_regfile_addr),
    .hart_regfile_wdata(hart_regfile_wdata),
    .hart_regfile_we   (hart_regfile_we),
    .hart_regfile_rdata(hart_regfile_rdata),
    .hart_pc_wdata     (hart_pc_wdata),
    .hart_pc_we        (hart_pc_we),
    .hart_pc_rdata     (hart_pc_rdata),

    // Program buffer
    .progbuf_instr     (progbuf_instr),
    .progbuf_exec      (progbuf_exec),
    .progbuf_done      (progbuf_done),
    .progbuf_exception (progbuf_exception),

    // TMR telemetry
    .tmr_pc_error      (tmr_pc_error),
    .tmr_fsm_error     (tmr_fsm_error),
    .tmr_rf_error      (tmr_rf_error),
    .tmr_ir_error      (tmr_ir_error),

    // AXI master: instruction fetch.
    .imem_araddr       (imem_araddr),
    .imem_arvalid      (imem_arvalid),
    .imem_arready      (imem_arready),
    .imem_rdata        (imem_rdata),
    .imem_rresp        (imem_rresp),
    .imem_rvalid       (imem_rvalid),
    .imem_rready       (imem_rready),

    // AXI master: data bus.
    .m_awaddr          (cpu_m_awaddr),
    .m_awvalid         (cpu_m_awvalid),
    .m_awready         (cpu_m_awready),
    .m_wdata           (cpu_m_wdata),
    .m_wstrb           (cpu_m_wstrb),
    .m_wvalid          (cpu_m_wvalid),
    .m_wready          (cpu_m_wready),
    .m_bresp           (cpu_m_bresp),
    .m_bvalid          (cpu_m_bvalid),
    .m_bready          (cpu_m_bready),
    .m_araddr          (cpu_m_araddr),
    .m_arvalid         (cpu_m_arvalid),
    .m_arready         (cpu_m_arready),
    .m_rdata           (cpu_m_rdata),
    .m_rresp           (cpu_m_rresp),
    .m_rvalid          (cpu_m_rvalid),
    .m_rready          (cpu_m_rready)
);

// AXI4-Lite crossbar: 2 masters (CPU + DMA), 7 slaves.
axi4_lite_crossbar u_crossbar (
    .clk       (clk),
    .rst_n     (rst_n),

    // M0: CPU data bus
    .m0_awaddr (cpu_m_awaddr),  .m0_awvalid(cpu_m_awvalid), .m0_awready(cpu_m_awready),
    .m0_wdata  (cpu_m_wdata),   .m0_wstrb  (cpu_m_wstrb),
    .m0_wvalid (cpu_m_wvalid),  .m0_wready (cpu_m_wready),
    .m0_bresp  (cpu_m_bresp),   .m0_bvalid (cpu_m_bvalid),  .m0_bready (cpu_m_bready),
    .m0_araddr (cpu_m_araddr),  .m0_arvalid(cpu_m_arvalid), .m0_arready(cpu_m_arready),
    .m0_rdata  (cpu_m_rdata),   .m0_rresp  (cpu_m_rresp),
    .m0_rvalid (cpu_m_rvalid),  .m0_rready (cpu_m_rready),

    // M1: DMA master
    .m1_awaddr (dma_m_awaddr),  .m1_awvalid(dma_m_awvalid), .m1_awready(dma_m_awready),
    .m1_wdata  (dma_m_wdata),   .m1_wstrb  (dma_m_wstrb),
    .m1_wvalid (dma_m_wvalid),  .m1_wready (dma_m_wready),
    .m1_bresp  (dma_m_bresp),   .m1_bvalid (dma_m_bvalid),  .m1_bready (dma_m_bready),
    .m1_araddr (dma_m_araddr),  .m1_arvalid(dma_m_arvalid), .m1_arready(dma_m_arready),
    .m1_rdata  (dma_m_rdata),   .m1_rresp  (dma_m_rresp),
    .m1_rvalid (dma_m_rvalid),  .m1_rready (dma_m_rready),

    // Slave port arrays
    .s_awaddr (s_awaddr),   .s_awvalid(s_awvalid), .s_awready(s_awready),
    .s_wdata  (s_wdata),    .s_wstrb  (s_wstrb),
    .s_wvalid (s_wvalid),   .s_wready (s_wready),
    .s_bresp  (s_bresp),    .s_bvalid (s_bvalid),  .s_bready (s_bready),
    .s_araddr (s_araddr),   .s_arvalid(s_arvalid), .s_arready(s_arready),
    .s_rdata  (s_rdata),    .s_rresp  (s_rresp),
    .s_rvalid (s_rvalid),   .s_rready (s_rready)
);

// SLV_IMEM (slot 0): null slave.
axi4_lite_null_slave u_null (
    .clk     (clk),
    .rst_n   (rst_n),
    .s_awaddr(s_awaddr [SLV_IMEM]), .s_awvalid(s_awvalid[SLV_IMEM]), .s_awready(s_awready[SLV_IMEM]),
    .s_wdata (s_wdata  [SLV_IMEM]), .s_wstrb  (s_wstrb  [SLV_IMEM]),
    .s_wvalid(s_wvalid [SLV_IMEM]), .s_wready (s_wready [SLV_IMEM]),
    .s_bresp (s_bresp  [SLV_IMEM]), .s_bvalid (s_bvalid [SLV_IMEM]), .s_bready(s_bready[SLV_IMEM]),
    .s_araddr(s_araddr [SLV_IMEM]), .s_arvalid(s_arvalid[SLV_IMEM]), .s_arready(s_arready[SLV_IMEM]),
    .s_rdata (s_rdata  [SLV_IMEM]), .s_rresp  (s_rresp  [SLV_IMEM]),
    .s_rvalid(s_rvalid [SLV_IMEM]), .s_rready (s_rready [SLV_IMEM])
);

// Direct IMEM slave for instruction fetch.
axi4_lite_mem_slave #(
    .WORDS   (512),
    .MEM_INIT("/home/sonia/riscv-hardware-debug-platform/sw/uart_hello/uart_hello_words.memh")
) u_imem (
    .clk      (clk),
    .rst_n    (rst_n),

    // IMEM is read-only from the CPU side.
    .s_awaddr (32'b0),  .s_awvalid(1'b0),  .s_awready(imem_awready_unused),
    .s_wdata  (32'b0),  .s_wstrb  (4'b0),  .s_wvalid (1'b0),  .s_wready(imem_wready_unused),
    .s_bresp  (imem_bresp_unused), .s_bvalid(imem_bvalid_unused), .s_bready(1'b0),

    // CPU instruction fetch port.
    .s_araddr (imem_araddr),
    .s_arvalid(imem_arvalid),
    .s_arready(imem_arready),
    .s_rdata  (imem_rdata),
    .s_rresp  (imem_rresp),
    .s_rvalid (imem_rvalid),
    .s_rready (imem_rready),

    // ECC telemetry : health slave directly
    .corrected(imem_corrected),
    .detected (imem_detected)
);

// SLV_DMEM (slot 1): DMEM slave.
axi4_lite_mem_slave #(
    .WORDS   (512),
    .MEM_INIT("/home/sonia/riscv-hardware-debug-platform/sw/uart_hello/uart_hello_dmem.memh"),
    .IS_DMEM (1)
) u_dmem (
    .clk      (clk),
    .rst_n    (rst_n),
    .s_awaddr (s_awaddr [SLV_DMEM]), .s_awvalid(s_awvalid[SLV_DMEM]), .s_awready(s_awready[SLV_DMEM]),
    .s_wdata  (s_wdata  [SLV_DMEM]), .s_wstrb  (s_wstrb  [SLV_DMEM]),
    .s_wvalid (s_wvalid [SLV_DMEM]), .s_wready (s_wready [SLV_DMEM]),
    .s_bresp  (s_bresp  [SLV_DMEM]), .s_bvalid (s_bvalid [SLV_DMEM]), .s_bready(s_bready[SLV_DMEM]),
    .s_araddr (s_araddr [SLV_DMEM]), .s_arvalid(s_arvalid[SLV_DMEM]), .s_arready(s_arready[SLV_DMEM]),
    .s_rdata  (s_rdata  [SLV_DMEM]), .s_rresp  (s_rresp  [SLV_DMEM]),
    .s_rvalid (s_rvalid [SLV_DMEM]), .s_rready (s_rready [SLV_DMEM]),
    .corrected(dmem_corrected),
    .detected (dmem_detected)
);

// SLV_UART (slot 2): UART TX slave.
axi4_lite_uart_slave #(
    .CLK_FREQ (100_000_000), // for Arty A7
    .BAUD_RATE(115_200)
) u_uart (
    .clk        (clk),
    .rst_n      (rst_n),
    .s_awaddr   (s_awaddr [SLV_UART]), .s_awvalid(s_awvalid[SLV_UART]), .s_awready(s_awready[SLV_UART]),
    .s_wdata    (s_wdata  [SLV_UART]), .s_wstrb  (s_wstrb  [SLV_UART]),
    .s_wvalid   (s_wvalid [SLV_UART]), .s_wready (s_wready [SLV_UART]),
    .s_bresp    (s_bresp  [SLV_UART]), .s_bvalid (s_bvalid [SLV_UART]), .s_bready(s_bready[SLV_UART]),
    .s_araddr   (s_araddr [SLV_UART]), .s_arvalid(s_arvalid[SLV_UART]), .s_arready(s_arready[SLV_UART]),
    .s_rdata    (s_rdata  [SLV_UART]), .s_rresp  (s_rresp  [SLV_UART]),
    .s_rvalid   (s_rvalid [SLV_UART]), .s_rready (s_rready [SLV_UART]),
    .uart_tx_pin(uart_tx)
);

// SLV_TIMER (slot 3): Timer/WDT slave.
axi4_lite_timer_slave u_timer (
    .clk      (clk),
    .rst_n    (rst_n),
    .s_awaddr (s_awaddr [SLV_TIMER]), .s_awvalid(s_awvalid[SLV_TIMER]), .s_awready(s_awready[SLV_TIMER]),
    .s_wdata  (s_wdata  [SLV_TIMER]), .s_wstrb  (s_wstrb  [SLV_TIMER]),
    .s_wvalid (s_wvalid [SLV_TIMER]), .s_wready (s_wready [SLV_TIMER]),
    .s_bresp  (s_bresp  [SLV_TIMER]), .s_bvalid (s_bvalid [SLV_TIMER]), .s_bready(s_bready[SLV_TIMER]),
    .s_araddr (s_araddr [SLV_TIMER]), .s_arvalid(s_arvalid[SLV_TIMER]), .s_arready(s_arready[SLV_TIMER]),
    .s_rdata  (s_rdata  [SLV_TIMER]), .s_rresp  (s_rresp  [SLV_TIMER]),
    .s_rvalid (s_rvalid [SLV_TIMER]), .s_rready (s_rready [SLV_TIMER]),
    .timer_irq(timer_irq),
    .wdt_reset(wdt_reset)
);

// SLV_HEALTH (slot 4): Health monitor slave.
axi4_lite_health_slave u_health (
    .clk            (clk),
    .rst_n          (rst_n),
    .s_awaddr       (s_awaddr [SLV_HEALTH]), .s_awvalid(s_awvalid[SLV_HEALTH]), .s_awready(s_awready[SLV_HEALTH]),
    .s_wdata        (s_wdata  [SLV_HEALTH]), .s_wstrb  (s_wstrb  [SLV_HEALTH]),
    .s_wvalid       (s_wvalid [SLV_HEALTH]), .s_wready (s_wready [SLV_HEALTH]),
    .s_bresp        (s_bresp  [SLV_HEALTH]), .s_bvalid (s_bvalid [SLV_HEALTH]), .s_bready(s_bready[SLV_HEALTH]),
    .s_araddr       (s_araddr [SLV_HEALTH]), .s_arvalid(s_arvalid[SLV_HEALTH]), .s_arready(s_arready[SLV_HEALTH]),
    .s_rdata        (s_rdata  [SLV_HEALTH]), .s_rresp  (s_rresp  [SLV_HEALTH]),
    .s_rvalid       (s_rvalid [SLV_HEALTH]), .s_rready (s_rready [SLV_HEALTH]),

    // ECC signals from memory slaves : direct wires, do not pass through CPU
    .imem_corrected (imem_corrected),
    .imem_detected  (imem_detected),
    .dmem_corrected (dmem_corrected),
    .dmem_detected  (dmem_detected),

    // TMR signals from CPU
    .tmr_pc_error   (tmr_pc_error),
    .tmr_fsm_error  (tmr_fsm_error),
    .tmr_rf_error   (tmr_rf_error),
    .tmr_ir_error   (tmr_ir_error),

    .health_irq     (health_irq)
);

// SLV_FIR (slot 5): FIR accelerator slave.
axi4_lite_fir_slave u_fir (
    .clk      (clk),
    .rst_n    (rst_n),
    .s_awaddr (s_awaddr [SLV_FIR]), .s_awvalid(s_awvalid[SLV_FIR]), .s_awready(s_awready[SLV_FIR]),
    .s_wdata  (s_wdata  [SLV_FIR]), .s_wstrb  (s_wstrb  [SLV_FIR]),
    .s_wvalid (s_wvalid [SLV_FIR]), .s_wready (s_wready [SLV_FIR]),
    .s_bresp  (s_bresp  [SLV_FIR]), .s_bvalid (s_bvalid [SLV_FIR]), .s_bready(s_bready[SLV_FIR]),
    .s_araddr (s_araddr [SLV_FIR]), .s_arvalid(s_arvalid[SLV_FIR]), .s_arready(s_arready[SLV_FIR]),
    .s_rdata  (s_rdata  [SLV_FIR]), .s_rresp  (s_rresp  [SLV_FIR]),
    .s_rvalid (s_rvalid [SLV_FIR]), .s_rready (s_rready [SLV_FIR])
);

// SLV_DMA (slot 6) DMA controller slave for CPU config, master for data movement.
dma_ctrl u_dma (
    .clk      (clk),
    .rst_n    (rst_n),

    // Slave: CPU programs DMA registers via crossbar
    .s_awaddr (s_awaddr [SLV_DMA]), .s_awvalid(s_awvalid[SLV_DMA]), .s_awready(s_awready[SLV_DMA]),
    .s_wdata  (s_wdata  [SLV_DMA]), .s_wstrb  (s_wstrb  [SLV_DMA]),
    .s_wvalid (s_wvalid [SLV_DMA]), .s_wready (s_wready [SLV_DMA]),
    .s_bresp  (s_bresp  [SLV_DMA]), .s_bvalid (s_bvalid [SLV_DMA]), .s_bready(s_bready[SLV_DMA]),
    .s_araddr (s_araddr [SLV_DMA]), .s_arvalid(s_arvalid[SLV_DMA]), .s_arready(s_arready[SLV_DMA]),
    .s_rdata  (s_rdata  [SLV_DMA]), .s_rresp  (s_rresp  [SLV_DMA]),
    .s_rvalid (s_rvalid [SLV_DMA]), .s_rready (s_rready [SLV_DMA]),

    // Master: DMA drives crossbar M1 port independently
    .m_awaddr (dma_m_awaddr),  .m_awvalid(dma_m_awvalid), .m_awready(dma_m_awready),
    .m_wdata  (dma_m_wdata),   .m_wstrb  (dma_m_wstrb),
    .m_wvalid (dma_m_wvalid),  .m_wready (dma_m_wready),
    .m_bresp  (dma_m_bresp),   .m_bvalid (dma_m_bvalid),  .m_bready (dma_m_bready),
    .m_araddr (dma_m_araddr),  .m_arvalid(dma_m_arvalid), .m_arready(dma_m_arready),
    .m_rdata  (dma_m_rdata),   .m_rresp  (dma_m_rresp),
    .m_rvalid (dma_m_rvalid),  .m_rready (dma_m_rready),

    .dma_irq  (dma_irq)
);

endmodule : soc_top
