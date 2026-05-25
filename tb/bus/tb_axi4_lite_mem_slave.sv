`timescale 1ns/1ps
module tb_axi4_lite_mem_slave;

logic clk;
logic rst_n;

logic [31:0] awaddr;
logic        awvalid;
logic        awready;

logic [31:0] wdata;
logic [3:0]  wstrb;
logic        wvalid;
logic        wready;

logic [1:0]  bresp;
logic        bvalid;
logic        bready;

logic [31:0] araddr;
logic        arvalid;
logic        arready;

logic [31:0] rdata;
logic [1:0]  rresp;
logic        rvalid;
logic        rready;

logic corrected;
logic detected;

axi4_lite_mem_slave #(
    .WORDS   (128),
    .MEM_INIT("")
) dut (
    .clk       (clk),
    .rst_n     (rst_n),
 
    .s_awaddr  (awaddr),
    .s_awvalid (awvalid),
    .s_awready (awready),
 
    .s_wdata   (wdata),
    .s_wstrb   (wstrb),
    .s_wvalid  (wvalid),
    .s_wready  (wready),
 
    .s_bresp   (bresp),
    .s_bvalid  (bvalid),
    .s_bready  (bready),
 
    .s_araddr  (araddr),
    .s_arvalid (arvalid),
    .s_arready (arready),
 
    .s_rdata   (rdata),
    .s_rresp   (rresp),
    .s_rvalid  (rvalid),
    .s_rready  (rready),
 
    .corrected (corrected),
    .detected  (detected)
);

initial clk = 0;
always #5 clk = ~clk;

initial begin
    awaddr  = '0; awvalid = 0;
    wdata   = '0; wstrb   = 4'b1111; wvalid = 0;
    bready  = 0;
    araddr  = '0; arvalid = 0;
    rready  = 0;
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
    w_done  = 0;
    while (!aw_done || !w_done) begin
        @(posedge clk);
        if (!aw_done && awready) aw_done = 1;
        if (!w_done && wready)   w_done  = 1;
        @(negedge clk);
        if (aw_done) awvalid = 0;
        if (w_done)  wvalid  = 0;
    end

    //slave -> master: bvalid, bresp
    // master -> slave: bready
    @(negedge clk);
    bready = 1;
    do @(posedge clk); while (!bvalid);
    resp   = bresp;
    @(negedge clk);
    bready = 0;
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

int pass_count = 0;
int fail_count = 0;

task automatic check(
    input string    test_name,
    input logic     condition
);
    if (condition) begin
        $display("  ✅ PASS  %s", test_name);
        pass_count++;
    end else begin
        $display("  ❌ FAIL  %s", test_name);
        fail_count++;
    end
endtask


logic [31:0] rd_data;
logic [1:0]  rd_resp, wr_resp;

initial begin
    rst_n = 0;
    repeat(4) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);
    $display("--- TEST 1: Word write / word read ---");
    axi_write(32'h0000_0000, 32'hDEAD_BEEF, 4'b1111, wr_resp);
    check("T1 write response OKAY",   wr_resp == 2'b00);
    axi_read (32'h0000_0000, rd_data,        rd_resp);
    check("T1 read response OKAY",    rd_resp == 2'b00);
    check("T1 read data = 0xDEADBEEF", rd_data == 32'hDEAD_BEEF);

    $display("");
    $display("--- TEST 2: Byte write partial update ---");
    axi_write(32'h0000_0004, 32'hAABB_CCDD, 4'b1111, wr_resp);
    check("T2 initial write OKAY", wr_resp == 2'b00);
    axi_write(32'h0000_0004, 32'h0000_0011, 4'b0001, wr_resp);
    check("T2 byte write OKAY",    wr_resp == 2'b00);
    axi_read (32'h0000_0004, rd_data, rd_resp);
    check("T2 byte 0 updated to 0x11",    rd_data[7:0]   == 8'h11);
    check("T2 byte 1 unchanged (0xCC)",   rd_data[15:8]  == 8'hCC);
    check("T2 byte 2 unchanged (0xBB)",   rd_data[23:16] == 8'hBB);
    check("T2 byte 3 unchanged (0xAA)",   rd_data[31:24] == 8'hAA);
    $display("");
    $display("--- TEST 3: ECC single-bit fault injection ---");
    axi_write(32'h0000_0008, 32'h1234_5678, 4'b1111, wr_resp);
    check("T3 write OKAY", wr_resp == 2'b00);

    dut.u_mem.mem[2][0] = ~dut.u_mem.mem[2][0];
    @(posedge clk); 


    axi_read(32'h0000_0008, rd_data, rd_resp);
    check("T3 read response OKAY",          rd_resp  == 2'b00);
    check("T3 corrected pulsed high",        corrected == 1'b1);
    check("T3 detected stayed low",          detected  == 1'b0);
    check("T3 returned data is correct",     rd_data  == 32'h1234_5678);
    $display("");
    $display("=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
    $display("");
    $finish;
end 

initial begin
    #100000;
    $display("TIMEOUT — simulation exceeded 100000 ns. Handshake probably stuck.");
    $finish;
end

endmodule
