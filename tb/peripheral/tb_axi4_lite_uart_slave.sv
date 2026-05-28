`timescale 1ns/1ps
module tb_axi4_lite_uart_slave;
localparam int CLK_FREQ       = 100;
localparam int BAUD_RATE      = 10;
localparam int CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE; // 10

logic clk;
logic rst_n;

initial clk = 0;
always #5 clk = ~clk; // 10 ns

logic [31:0] awaddr;  logic awvalid; logic awready;
logic [31:0] wdata;   logic [3:0] wstrb; logic wvalid; logic wready;
logic [1:0]  bresp;   logic bvalid;  logic bready;
logic [31:0] araddr;  logic arvalid; logic arready;
logic [31:0] rdata;   logic [1:0] rresp; logic rvalid; logic rready;
logic        uart_tx_pin;

axi4_lite_uart_slave #(
    .CLK_FREQ (CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)
) dut (
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

    .uart_tx_pin(uart_tx_pin)
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

task automatic sample_bit(output logic val);
    repeat(CYCLES_PER_BIT / 2) @(posedge clk); // sample in the middle 
    val = uart_tx_pin;
    repeat(CYCLES_PER_BIT / 2) @(posedge clk);
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

logic [31:0] rd_data;
logic [1:0]  rd_resp, wr_resp;

logic sampled_bits [0:9];

initial begin 
    rst_n = 0;
    repeat(4) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

    check("TX idle before any write", uart_tx_pin == 1'b1); // idle
    $display("");
    $display("--- TEST 1: 8N1 bit pattern for 'A' (0x41) ---");
    fork
        begin 
            axi_write(32'h2000_0000, 32'h0000_0041, 4'b1111, wr_resp);
            check("T1 write response OKAY", wr_resp == 2'b00);
        end     

        begin 
            @(negedge uart_tx_pin); // falling edge of starting bit

            for (int i = 0; i < 10; i++) begin
                sample_bit(sampled_bits[i]);
            end
        end 
    join
    check("T1 start bit = 0",  sampled_bits[0] == 1'b0);
    check("T1 data bit0 = 1",  sampled_bits[1] == 1'b1);
    check("T1 data bit1 = 0",  sampled_bits[2] == 1'b0);
    check("T1 data bit2 = 0",  sampled_bits[3] == 1'b0);
    check("T1 data bit3 = 0",  sampled_bits[4] == 1'b0);
    check("T1 data bit4 = 0",  sampled_bits[5] == 1'b0);
    check("T1 data bit5 = 0",  sampled_bits[6] == 1'b0);
    check("T1 data bit6 = 1",  sampled_bits[7] == 1'b1);
    check("T1 data bit7 = 0",  sampled_bits[8] == 1'b0);
    check("T1 stop bit  = 1",  sampled_bits[9] == 1'b1);
    $display("");
    $display("--- TEST 2: STATUS reads tx_busy=1 during transmission ---");
    fork
        begin 
            axi_write(32'h2000_0000, 32'h0000_0042, 4'b1111, wr_resp); // 'B'
        end

        begin 
            @(negedge uart_tx_pin);
            axi_read(32'h2000_0004, rd_data, rd_resp);
            check("T2 STATUS read OKAY",      rd_resp    == 2'b00);
            check("T2 tx_busy = 1 mid-frame", rd_data[0] == 1'b1);            
        end 
    join
    @(posedge clk);
    while (dut.u_uart_tx.tx_busy) @(posedge clk);
    repeat(2) @(posedge clk);

    $display("");
    $display("--- TEST 3: STATUS reads tx_busy=0 after transmission ---");
    axi_read(32'h2000_0004, rd_data, rd_resp);
    check("T3 STATUS read OKAY",       rd_resp    == 2'b00);
    check("T3 tx_busy = 0 after done", rd_data[0] == 1'b0);
    check("T3 TX pin idle high", uart_tx_pin == 1'b1);

    $display("");
    $display("=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
    $display("");
    $finish;
end

initial begin
    #100000;
    $display("TIMEOUT — simulation hung. Handshake or UART transmission stuck.");
    $finish;
end

endmodule 
