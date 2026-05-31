`timescale 1ns/1ps
// 8N1 UART transmitter
module uart_tx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input  logic clk,
    input  logic rst_n,

    // cpu interface 
    input  logic [7:0] tx_data,  
    input  logic       tx_start, 
    output logic       tx_busy,

    // Physical pin
    output logic       tx
);

localparam int CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE;
localparam int CTR_BITS = $clog2(CYCLES_PER_BIT + 1);
logic [CTR_BITS-1:0] baud_ctr;
logic                baud_tick;

assign baud_tick = (baud_ctr == CTR_BITS'(CYCLES_PER_BIT - 1));

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        baud_ctr <= '0;
    end else if (tx_busy) begin
        baud_ctr <= baud_tick ? '0 : baud_ctr + 1'b1;
    end else begin
        baud_ctr <= '0; 
    end
end

typedef enum logic [1:0] {
    TX_IDLE,
    TX_START,
    TX_DATA,
    TX_STOP
} tx_state_t;

tx_state_t  tx_state;
logic [7:0] shift_reg; 
logic [2:0] bit_idx; 

always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin
        tx_state  <= TX_IDLE;
        shift_reg <= '0;
        bit_idx   <= '0;
        tx        <= 1'b1; // idle high
    end else begin
        case (tx_state)
            TX_IDLE: begin
                tx <= 1'b1; // hold idle
                if (tx_start) begin
                    shift_reg <= tx_data;
                    tx_state  <= TX_START;
                end
            end
            TX_START: begin
                tx <= 1'b0; // start bit — pull low
                if (baud_tick) begin
                    bit_idx  <= 3'd0;
                    tx_state <= TX_DATA;
                end
            end
            TX_DATA: begin
                tx <= shift_reg[0]; // LSB first
                if (baud_tick) begin
                    shift_reg <= {1'b0, shift_reg[7:1]}; // shift right
                    if (bit_idx == 3'd7) begin
                        tx_state <= TX_STOP;
                    end else begin
                        bit_idx <= bit_idx + 1'b1;
                    end
                end
            end
            TX_STOP: begin
                tx <= 1'b1; // stop bit — return high
                if (baud_tick) begin
                    tx_state <= TX_IDLE;
                end
            end
            default: tx_state <= TX_IDLE;
        endcase 
    end 

end 

assign tx_busy = (tx_state != TX_IDLE);
endmodule
