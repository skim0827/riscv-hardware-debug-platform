`timescale 1ns/1ps

module tb_fir;

localparam int TAPS     = 8;
localparam int CLK_HALF = 5; // 100 MHz

// Expected impulse response for input 16384 (0.5 in Q1.15)
// Computed as: h[k] * 16384 >> 15 (floor)
localparam signed [15:0] EXP[0:TAPS-1] = '{
    -16'sd27,   // -53*16384>>15 = -27
    16'sd0,     
    16'sd997,   // 1995*16384>>15 = 997
    16'sd2048,  // 4096*16384>>15 = 2048
    16'sd2048,  
    16'sd997,   
    16'sd0,    
    -16'sd27
};

logic clk = 0;
always #CLK_HALF clk = ~clk;

task automatic tick(input int n = 1);
    repeat(n) @(posedge clk); #1;
endtask

logic        rst_n;
logic signed [15:0] fir_din, fir_dout;
logic        fir_vin, fir_vout, fir_rout; // fir_rout = 1

fir_filter u_fir (
    .clk      (clk),
    .rst_n    (rst_n),
    .data_in  (fir_din),
    .valid_in (fir_vin),
    .ready_out(fir_rout),
    .data_out (fir_dout),
    .valid_out(fir_vout)
);

logic [31:0] awaddr, wdata, araddr, rdata;
logic [3:0]  wstrb;
logic        awvalid, awready, wvalid, wready;
logic [1:0]  bresp;
logic        bvalid, bready;
logic        arvalid, arready;
logic [1:0]  rresp;
logic        rvalid, rready;

axi4_lite_fir_slave u_axi (
    .clk      (clk),   .rst_n    (rst_n),
    .s_awaddr (awaddr), .s_awvalid(awvalid), .s_awready(awready),
    .s_wdata  (wdata),  .s_wstrb  (wstrb),   .s_wvalid (wvalid),  .s_wready (wready),
    .s_bresp  (bresp),  .s_bvalid (bvalid),  .s_bready (bready),
    .s_araddr (araddr), .s_arvalid(arvalid), .s_arready(arready),
    .s_rdata  (rdata),  .s_rresp  (rresp),   .s_rvalid (rvalid),  .s_rready (rready)
);


task automatic axi_write(input logic [31:0] addr, input logic [31:0] d);
    @(posedge clk); #1;
    awaddr = addr; awvalid = 1;
    wdata  = d;    wstrb   = 4'hF; wvalid = 1;
    fork
        begin wait(awready); @(posedge clk); #1; awvalid = 0; end
        begin wait(wready);  @(posedge clk); #1; wvalid  = 0; end
    join
    bready = 1;
    wait(bvalid); @(posedge clk); #1;
    bready = 0;
endtask

task automatic axi_read(input logic [31:0] addr, output logic [31:0] d);
    @(posedge clk); #1;
    araddr = addr; arvalid = 1;
    wait(arready); @(posedge clk); #1;
    arvalid = 0;
    rready = 1;
    wait(rvalid); d = rdata; @(posedge clk); #1;
    rready = 0;
endtask


int pass_cnt, fail_cnt;

task automatic check(
    input string      label,
    input signed [15:0] got,
    input signed [15:0] exp
);
    int g, e;
    g = int'(got);
    e = int'(exp);
    if (g >= e-1 && g <= e+1) begin
        $display("  ✅ PASS  %s: got=%0d exp=%0d", label, g, e);
        pass_cnt++;
    end else begin
        $display("  ❌ FAIL  %s: got=%0d exp=%0d", label, g, e);
        fail_cnt++;
    end
endtask


initial begin
    rst_n = 0; fir_din = 0; fir_vin = 0;
    awvalid = 0; wvalid = 0; bready = 0; arvalid = 0; rready = 0;
    awaddr = 0; wdata = 0; wstrb = 0; araddr = 0;
    pass_cnt = 0; fail_cnt = 0;

    tick(4); rst_n = 1; tick(2);


    $display("\n=== TEST 1: Direct FIR impulse (x[0]=16384) ===");
    fir_vin = 1; fir_din = 16384;// impulse
    @(posedge clk); #1;
    fir_din = 0; // flush zeros

    wait(fir_vout); @(posedge clk); #1;

    for (int k = 0; k < TAPS; k++) begin
        wait(fir_vout);
        check($sformatf("fir_h[%0d]", k), fir_dout, EXP[k]);
        @(posedge clk); #1;
    end
    fir_vin = 0;

    tick(2); rst_n = 0; tick(2); rst_n = 1; tick(2);

    $display("\n=== TEST 2: AXI slave impulse (0x000 writes, 0x004 reads) ===");
    axi_write(32'h000, 32'h4000); // 16384

    for (int k = 0; k < TAPS; k++) begin
        logic [31:0] rd;
        axi_write(32'h000, 32'h0000); // flush zero
        axi_read (32'h004, rd);       // DATA_OUT: bit[16]=out_valid, [15:0]=out_reg
        if (!rd[16]) begin
            $display("  ❌ FAIL  axi_h[%0d]: out_valid=0 (no result)", k);
            fail_cnt++;
        end else begin
            check($sformatf("axi_h[%0d]", k), $signed(rd[15:0]), EXP[k]);
        end
    end


    $display("\n=== TEST 3: AXI status after idle ===");
    tick(4);
    begin
        logic [31:0] rd;
        axi_read(32'h008, rd); // FIR_STATUS: {busy, out_valid}

        if (rd[1:0] === 2'b00)
            $display("  ✅ PASS  status idle: 0x%08h", rd);
        else begin
            $display("  ❌ FAIL  status expected 0x0 got 0x%08h", rd);
            fail_cnt++;
        end
    end


    $display("\n=== TEST 4: AXI soft reset ===");
    // push a non-zero sample, then soft-reset, verify next output is 0
    axi_write(32'h000, 32'h7FFF); // large sample
    tick(3);
    axi_write(32'h00C, 32'h1);    // FIR_CTRL: soft reset
    tick(2);
    axi_write(32'h000, 32'h0);    // flush zero after reset
    begin
        logic [31:0] rd;
        axi_read(32'h004, rd); // DATA_OUT
        if (rd[16] === 1'b1 && rd[15:0] === 16'h0)
            $display("  ✅ PASS  soft reset: data=0 after reset");
        else begin
            $display("  ❌ FAIL  soft reset: got data=0x%04h valid=%0b", rd[15:0], rd[16]);
            fail_cnt++;
        end
    end


    $display("\n=== RESULTS: %0d passed, %0d failed ===\n", pass_cnt, fail_cnt);
    if (fail_cnt == 0) $display("✅ ALL PASS");
    else               $display("❌ FAILURES DETECTED");

    $finish;
end


initial begin
    #200000;
    $display("❌ TIMEOUT");
    $finish;
end

endmodule
