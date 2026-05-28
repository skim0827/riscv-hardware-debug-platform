`timescale 1ns/1ps
module tb_axi4_lite_timer_slave;
logic clk;
logic rst_n;

initial clk = 0;
always #5 clk = ~clk;   // 10 ns period


logic [31:0] awaddr;  logic awvalid; logic awready;
logic [31:0] wdata;   logic [3:0] wstrb; logic wvalid; logic wready;
logic [1:0]  bresp;   logic bvalid;  logic bready;
logic [31:0] araddr;  logic arvalid; logic arready;
logic [31:0] rdata;   logic [1:0] rresp; logic rvalid; logic rready;
logic        timer_irq;
logic        wdt_reset;

axi4_lite_timer_slave dut (
    .clk        (clk),
    .rst_n      (rst_n),

    .s_awaddr   (awaddr),
    .s_awvalid  (awvalid),
    .s_awready  (awready),
    .s_wdata    (wdata),
    .s_wstrb    (wstrb),
    .s_wvalid   (wvalid),
    .s_wready   (wready),
    .s_bresp    (bresp),
    .s_bvalid   (bvalid),
    .s_bready   (bready),
    .s_araddr   (araddr),
    .s_arvalid  (arvalid),
    .s_arready  (arready),
    .s_rdata    (rdata),
    .s_rresp    (rresp),
    .s_rvalid   (rvalid),
    .s_rready   (rready),

    .timer_irq  (timer_irq),
    .wdt_reset  (wdt_reset)
);

initial begin
    awaddr = '0; awvalid = 0;
    wdata  = '0; wstrb   = 4'b1111; wvalid = 0;
    bready = 0;
    araddr = '0; arvalid = 0;
    rready = 0;
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

// IRQ capture
logic irq_seen;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        irq_seen <= 1'b0;
    else if (timer_irq)
        irq_seen <= 1'b1;
end

logic [31:0] rd_data;
logic [1:0]  rd_resp, wr_resp;

localparam logic [31:0] TIMER_CTRL_ADDR    = 32'h2000_1000;
localparam logic [31:0] TIMER_COUNT_ADDR   = 32'h2000_1004;
localparam logic [31:0] TIMER_TIMEOUT_ADDR = 32'h2000_1008;
localparam logic [31:0] TIMER_STATUS_ADDR  = 32'h2000_100C;

initial begin
    do_reset();
    axi_write(TIMER_TIMEOUT_ADDR, 32'd50, 4'b1111, wr_resp);
    check("T4 write TIMEOUT OKAY", wr_resp == 2'b00);

    axi_write(TIMER_CTRL_ADDR, 32'h0000_0002, 4'b1111, wr_resp);
    check("T4 enable WDT OKAY", wr_resp == 2'b00);

    repeat(25) @(posedge clk); 
    axi_write(TIMER_CTRL_ADDR, 32'h0000_0006, 4'b1111, wr_resp);  // 3'b110 = wdt_kick=1, wdt_en=1, timer_en=0
    check("T4 WDT kick OKAY", wr_resp == 2'b00);

    repeat(35) @(posedge clk);
    check("T4 wdt_reset still 0 after kick", wdt_reset == 1'b0);

    axi_read(TIMER_STATUS_ADDR, rd_data, rd_resp);
    check("T4 STATUS bit[1] = 0", rd_data[1] == 1'b0);

    $display("");
    $display("=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
    $finish;
end 

initial begin
    #500000;
    $display("TIMEOUT — simulation exceeded 500000 ns.");
    $finish;
end
endmodule