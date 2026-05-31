module tb_axi4_lite_health_slave;

logic clk;
logic rst_n;

initial clk = 0;
always #5 clk = ~clk;

logic imem_corrected;
logic imem_detected;
logic dmem_corrected;
logic dmem_detected;
logic tmr_pc_error;
logic tmr_fsm_error;
logic tmr_rf_error;
logic tmr_ir_error;


logic [31:0] awaddr;  logic awvalid; logic awready;
logic [31:0] wdata;   logic [3:0] wstrb; logic wvalid; logic wready;
logic [1:0]  bresp;   logic bvalid;  logic bready;
logic [31:0] araddr;  logic arvalid; logic arready;
logic [31:0] rdata;   logic [1:0] rresp; logic rvalid; logic rready;
logic        health_irq;


axi4_lite_health_slave dut (
    .clk            (clk),
    .rst_n          (rst_n),

    .s_awaddr       (awaddr),
    .s_awvalid      (awvalid),
    .s_awready      (awready),
    .s_wdata        (wdata),
    .s_wstrb        (wstrb),
    .s_wvalid       (wvalid),
    .s_wready       (wready),
    .s_bresp        (bresp),
    .s_bvalid       (bvalid),
    .s_bready       (bready),
    .s_araddr       (araddr),
    .s_arvalid      (arvalid),
    .s_arready      (arready),
    .s_rdata        (rdata),
    .s_rresp        (rresp),
    .s_rvalid       (rvalid),
    .s_rready       (rready),

    .imem_corrected (imem_corrected),
    .imem_detected  (imem_detected),
    .dmem_corrected (dmem_corrected),
    .dmem_detected  (dmem_detected),
    .tmr_pc_error   (tmr_pc_error),
    .tmr_fsm_error  (tmr_fsm_error),
    .tmr_rf_error   (tmr_rf_error),
    .tmr_ir_error   (tmr_ir_error),

    .health_irq     (health_irq)
);

initial begin
    awaddr = '0; awvalid = 0;
    wdata  = '0; wstrb   = 4'b1111; wvalid = 0;
    bready = 0;
    araddr = '0; arvalid = 0;
    rready = 0;

    // All fault signals idle
    imem_corrected = 0; imem_detected  = 0;
    dmem_corrected = 0; dmem_detected  = 0;
    tmr_pc_error   = 0; tmr_fsm_error  = 0;
    tmr_rf_error   = 0; tmr_ir_error   = 0;
end



task automatic axi_write(
    input  logic [31:0] addr,
    input  logic [31:0] data,
    input  logic [3:0]  strb,
    output logic [1:0]  resp
);
    bit aw_done;
    bit w_done;
    @(negedge clk);
    awaddr  = addr;
    awvalid = 1;
    wdata   = data;
    wstrb   = strb;
    wvalid  = 1;

    aw_done = 0;
    w_done = 0;
    while (!aw_done || !w_done) begin
        @(posedge clk);
        if (!aw_done && awready) aw_done = 1;
        if (!w_done && wready)   w_done  = 1;
        @(negedge clk);
        if (aw_done) awvalid = 0;
        if (w_done)  wvalid  = 0;
    end

    @(negedge clk);
    bready  = 1;
    do @(posedge clk); while (!bvalid);
    resp    =  bresp;
    @(negedge clk);
    bready  = 0;
    @(posedge clk);
endtask


task automatic axi_read(
    input  logic [31:0] addr,
    output logic [31:0] data,
    output logic [1:0]  resp
);

    @(negedge clk);
    araddr  = addr;
    arvalid = 1;

    do @(posedge clk); while (!arready);
    @(negedge clk);
    arvalid = 0;

    @(negedge clk);
    rready = 1;
    do @(posedge clk); while (!rvalid);
    data   = rdata;
    resp   = rresp;
    @(negedge clk);
    rready = 0;
    @(posedge clk);

endtask 

task automatic pulse_fault(ref logic sig);
    @(posedge clk);
    sig = 1;
    @(posedge clk);
    sig = 0;
    @(posedge clk); // settle
endtask

task automatic do_reset();
    rst_n = 0;
    repeat(4) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);
endtask

int pass_count = 0;
int fail_count = 0;

task automatic check(input string name, input logic condition);
    if (condition) begin
        $display("  ✅ PASS  %s", name);
        pass_count++;
    end else begin
        $display("  ❌ FAIL  %s", name);
        fail_count++;
    end
endtask

localparam logic [31:0] ADDR_ECC_CORR  = 32'h2000_2000;
localparam logic [31:0] ADDR_ECC_DET   = 32'h2000_2004;
localparam logic [31:0] ADDR_TMR_PC    = 32'h2000_2008;
localparam logic [31:0] ADDR_TMR_FSM   = 32'h2000_200C;
localparam logic [31:0] ADDR_TMR_RF    = 32'h2000_2010;
localparam logic [31:0] ADDR_TMR_IR    = 32'h2000_2014;
localparam logic [31:0] ADDR_STATUS    = 32'h2000_2018;
localparam logic [31:0] ADDR_IRQ_MASK  = 32'h2000_201C;
localparam logic [31:0] ADDR_IRQ_STAT  = 32'h2000_2020;
localparam logic [31:0] ADDR_CTRL      = 32'h2000_2024;

// =============================================================================
// bit[0] = imem_corrected
// bit[1] = imem_detected
// bit[2] = dmem_corrected
// bit[3] = dmem_detected
// bit[4] = tmr_pc_error
// bit[5] = tmr_fsm_error
// bit[6] = tmr_rf_error
// bit[7] = tmr_ir_error
// bit[31:8] = unused / 0
// =============================================================================
logic [31:0] rd_data;
logic [1:0]  rd_resp, wr_resp;
initial begin
    do_reset();
    $display("");
    $display("--- TEST 1: imem_corrected increments ECC_CORR_CNT ---");

    pulse_fault(imem_corrected);
    axi_read(ADDR_ECC_CORR, rd_data, rd_resp);
    check("T1 read OKAY",            rd_resp == 2'b00);
    check("T1 ECC_CORR_CNT = 1",     rd_data == 32'd1);
    axi_read(ADDR_ECC_DET,  rd_data, rd_resp);
    check("T1 ECC_DET_CNT = 0",      rd_data == 32'd0);
    axi_read(ADDR_TMR_PC,   rd_data, rd_resp);
    check("T1 TMR_PC_CNT = 0",       rd_data == 32'd0);

    $display("");
    $display("--- TEST 2: Three tmr_pc_error pulses → TMR_PC_CNT = 3 ---");
    pulse_fault(tmr_pc_error);
    pulse_fault(tmr_pc_error);
    pulse_fault(tmr_pc_error);
    axi_read(ADDR_TMR_PC, rd_data, rd_resp);
    check("T2 read OKAY",        rd_resp == 2'b00);
    check("T2 TMR_PC_CNT = 3",   rd_data == 32'd3);
    axi_read(ADDR_ECC_CORR, rd_data, rd_resp);
    check("T2 ECC_CORR_CNT still 1", rd_data == 32'd1);
    $display("");
    $display("--- TEST 3: IRQ fires for unmasked dmem_detected ---");
    axi_write(ADDR_IRQ_MASK, 32'h0000_00FF, 4'b1111, wr_resp);
    check("T3 IRQ_MASK write OKAY", wr_resp == 2'b00);
    do_reset();
    axi_write(ADDR_IRQ_MASK, 32'h0000_00FF, 4'b1111, wr_resp);
    check("T3 IRQ_MASK write OKAY", wr_resp == 2'b00);
    pulse_fault(dmem_detected);
    @(posedge clk);
    check("T3 health_irq asserted",      health_irq == 1'b1);
    axi_read(ADDR_IRQ_STAT, rd_data, rd_resp);
    check("T3 IRQ_STATUS read OKAY",     rd_resp    == 2'b00);
    check("T3 IRQ_STATUS bit[3] = 1",    rd_data[3] == 1'b1);

    $display("");
    $display("--- TEST 4: W1C clears IRQ_STATUS, health_irq deasserts ---");
    axi_write(ADDR_IRQ_STAT, 32'h0000_00FF, 4'b1111, wr_resp);
    check("T4 W1C write OKAY", wr_resp == 2'b00);
    @(posedge clk);
    check("T4 health_irq deasserted",    health_irq == 1'b0);
    axi_read(ADDR_IRQ_STAT, rd_data, rd_resp);
    check("T4 IRQ_STATUS read OKAY",     rd_resp    == 2'b00);
    check("T4 IRQ_STATUS bit[3] = 0",    rd_data[3] == 1'b0);
    check("T4 IRQ_STATUS = 0",           rd_data    == 32'b0);
    $display("");
    $display("--- TEST 5: CTRL clear resets all counters to 0 ---");

    @(posedge clk);
    imem_corrected = 1; imem_detected = 1;
    dmem_corrected = 1; dmem_detected = 1;
    tmr_pc_error   = 1; tmr_fsm_error = 1;
    tmr_rf_error   = 1; tmr_ir_error  = 1;
    @(posedge clk);
    imem_corrected = 0; imem_detected = 0;
    dmem_corrected = 0; dmem_detected = 0;
    tmr_pc_error   = 0; tmr_fsm_error = 0;
    tmr_rf_error   = 0; tmr_ir_error  = 0;
    @(posedge clk);

    axi_read(ADDR_TMR_PC, rd_data, rd_resp);
    check("T5 TMR_PC_CNT non-zero before clear", rd_data > 32'd0);
    axi_write(ADDR_CTRL, 32'h0000_0001, 4'b1111, wr_resp);
    check("T5 CTRL write OKAY", wr_resp == 2'b00);
    @(posedge clk);

    axi_read(ADDR_ECC_CORR, rd_data, rd_resp);
    check("T5 ECC_CORR_CNT = 0 after clear", rd_data == 32'd0);

    axi_read(ADDR_ECC_DET,  rd_data, rd_resp);
    check("T5 ECC_DET_CNT = 0 after clear",  rd_data == 32'd0);

    axi_read(ADDR_TMR_PC,   rd_data, rd_resp);
    check("T5 TMR_PC_CNT = 0 after clear",   rd_data == 32'd0);

    axi_read(ADDR_TMR_FSM,  rd_data, rd_resp);
    check("T5 TMR_FSM_CNT = 0 after clear",  rd_data == 32'd0);

    axi_read(ADDR_TMR_RF,   rd_data, rd_resp);
    check("T5 TMR_RF_CNT = 0 after clear",   rd_data == 32'd0);

    axi_read(ADDR_TMR_IR,   rd_data, rd_resp);
    check("T5 TMR_IR_CNT = 0 after clear",   rd_data == 32'd0);

    $display("");
    $display("=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
    $display("");
    $finish;
end 

initial begin
    #500000;
    $display("TIMEOUT — simulation exceeded 500000 ns.");
    $finish;
end
endmodule 
