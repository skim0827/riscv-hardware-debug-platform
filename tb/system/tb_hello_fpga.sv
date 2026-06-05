`timescale 1ns/1ps
module tb_hello_fpga;

localparam int CLK_FREQ       = 100_000_000;
localparam int BAUD_RATE      = 115_200;
localparam int CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE; // 868

logic clk, rst_btn, uart_tx;
logic imem_corrected_o, imem_detected_o;
logic dmem_corrected_o, dmem_detected_o;
logic tmr_pc_error_o, tmr_fsm_error_o, tmr_rf_error_o, tmr_ir_error_o;
logic timer_irq_o, health_irq_o;

initial clk = 0;
always #5 clk = ~clk; // 100 MHz

soc_top dut (
    .clk              (clk),
    .rst_btn          (rst_btn),
    .uart_tx          (uart_tx),
    .imem_corrected_o (imem_corrected_o),
    .imem_detected_o  (imem_detected_o),
    .dmem_corrected_o (dmem_corrected_o),
    .dmem_detected_o  (dmem_detected_o),
    .tmr_pc_error_o   (tmr_pc_error_o),
    .tmr_fsm_error_o  (tmr_fsm_error_o),
    .tmr_rf_error_o   (tmr_rf_error_o),
    .tmr_ir_error_o   (tmr_ir_error_o),
    .timer_irq_o      (timer_irq_o),
    .health_irq_o     (health_irq_o)
);

// Receive one 8N1 UART byte, sampling in the middle of each bit period.
task automatic uart_recv_byte(output logic [7:0] data);
    @(negedge uart_tx);                             // falling edge = start bit
    repeat(CYCLES_PER_BIT / 2) @(posedge clk);     // advance to bit centre
    for (int i = 0; i < 8; i++) begin
        repeat(CYCLES_PER_BIT) @(posedge clk);
        data[i] = uart_tx;                          // LSB first (8N1)
    end
    repeat(CYCLES_PER_BIT) @(posedge clk);         // consume stop bit
endtask

// Expected output: "Hello FPGA!\r\n"
localparam int MSG_LEN = 13;
localparam logic [7:0] EXPECTED [0:12] = '{
    8'h48, 8'h65, 8'h6C, 8'h6C, 8'h6F,  // H e l l o
    8'h20,                                 // (space)
    8'h46, 8'h50, 8'h47, 8'h41,          // F P G A
    8'h21, 8'h0D, 8'h0A                  // ! CR LF
};

logic [7:0] rx_buf [0:12];
int pass_count, fail_count;

task automatic check(input string name, input logic cond);
    if (cond) begin
        $display("  ✅ PASS  %s", name);
        pass_count++;
    end else begin
        $display("  ❌ FAIL  %s", name);
        fail_count++;
    end
endtask

initial begin
    pass_count = 0;
    fail_count = 0;

    rst_btn = 1;
    repeat(4) @(posedge clk);
    rst_btn = 0;


    for (int i = 0; i < MSG_LEN; i++) begin
        uart_recv_byte(rx_buf[i]);
        $write("  rx[%2d] = 0x%02h", i, rx_buf[i]);
        if (rx_buf[i] >= 8'h20 && rx_buf[i] < 8'h7F)
            $write(" ('%c')", rx_buf[i]);
        else
            $write("      ");
        $write("   expected 0x%02h", EXPECTED[i]);
        $display("%s", (rx_buf[i] == EXPECTED[i]) ? "  OK" : "  MISMATCH");
    end

    $display("");
    $display("=== Byte-by-byte checks ===");
    for (int i = 0; i < MSG_LEN; i++)
        check($sformatf("rx[%0d] == 0x%02h", i, EXPECTED[i]),
              rx_buf[i] == EXPECTED[i]);

    $display("");
    $display("=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
    $finish;
end

// Timeout: 2M cycles >> 13 chars x 868 cycles/bit x 10 bits + CPU overhead
initial begin
    repeat(2_000_000) @(posedge clk);
    $display("❌ TIMEOUT — UART did not deliver all 13 bytes within 2M cycles.");
    $finish;
end

endmodule
