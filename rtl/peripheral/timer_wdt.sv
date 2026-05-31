/*
CTRL
  bit[0] = timer_en
  bit[1] = wdt_en
  bit[2] = wdt_kick

COUNT
  current timer counter value

TIMEOUT
  timeout threshold used by both timer and watchdog

STATUS
  bit[0] = timer_irq_pending
  bit[1] = wdt_fired
*/
`timescale 1ns/1ps
module timer_wdt (
    input  logic        clk,
    input  logic        rst_n,

    // Register interface (from AXI slave)
    input  logic [31:0] ctrl_i,
    output logic [31:0] count_o,
    input  logic [31:0] timeout_i,
    output logic [31:0] status_o,
    input  logic        irq_clear_i,

    // Outputs to system
    output logic        timer_irq,
    output logic        wdt_reset
);

// control register
logic timer_en;
logic wdt_en;
logic wdt_kick;
logic _unused_ctrl;

assign timer_en = ctrl_i[0];
assign wdt_en   = ctrl_i[1];
assign wdt_kick = ctrl_i[2];
assign _unused_ctrl = |ctrl_i[31:3];

// Timer counter
logic [31:0] timer_count;
logic        timer_match;
assign timer_match = timer_en && (timer_count == timeout_i) && (timeout_i != 32'b0);
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timer_count <= 32'b0;
    end else if (timer_en) begin
        if (timer_match)
            timer_count <= 32'b0;        // reset and keep counting
        else if (timer_count != 32'hFFFF_FFFF)
            timer_count <= timer_count + 1'b1;
    end else begin
        timer_count <= 32'b0;
    end
end

assign count_o = timer_count;

// Timer IRQ
logic timer_irq_pending;
assign timer_irq = timer_match;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        timer_irq_pending <= 1'b0;
    else if (irq_clear_i)
        timer_irq_pending <= 1'b0;
    else if (timer_match)
        timer_irq_pending <= 1'b1;
end


// Watchdog counter
logic [31:0] wdt_count;
logic        wdt_fired;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wdt_count <= 32'b0;
        wdt_fired <= 1'b0;
    end else if (wdt_fired) begin
        wdt_fired <= 1'b1;
        wdt_count <= wdt_count; // freeze
    end else if (wdt_kick) begin
        wdt_count <= 32'b0;
    end else if (wdt_en) begin
        if (wdt_count == timeout_i && timeout_i != 32'b0) begin
            wdt_fired <= 1'b1;
        end else if (wdt_count != 32'hFFFF_FFFF) begin
            wdt_count <= wdt_count + 1'b1;
        end
    end else begin
        wdt_count <= 32'b0;
    end
end
assign wdt_reset = wdt_fired;
// STATUS register output
assign status_o = {30'b0, wdt_fired, timer_irq_pending};

endmodule
