`timescale 1ns/1ps
module axi4_lite_uart_slave #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [31:0] s_awaddr,
    input  logic        s_awvalid,
    output logic        s_awready,

    input  logic [31:0] s_wdata,
    input  logic [3:0]  s_wstrb,
    input  logic        s_wvalid,
    output logic        s_wready,

    output logic [1:0]  s_bresp,
    output logic        s_bvalid,
    input  logic        s_bready,

    input  logic [31:0] s_araddr,
    input  logic        s_arvalid,
    output logic        s_arready,

    output logic [31:0] s_rdata,
    output logic [1:0]  s_rresp,
    output logic        s_rvalid,
    input  logic        s_rready,

    // Physical pin
    output logic        uart_tx_pin
);

import axi4_lite_pkg::*;
logic [7:0] tx_data;
logic       tx_start;
logic       tx_busy;

uart_tx #(
    .CLK_FREQ (CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)
) u_uart_tx (
    .clk     (clk),
    .rst_n   (rst_n),
    .tx_data (tx_data),
    .tx_start(tx_start),
    .tx_busy (tx_busy),
    .tx      (uart_tx_pin)
);

typedef enum logic [1:0] {
    WR_IDLE,
    WR_EXEC,
    WR_RESP
} wr_state_t;

wr_state_t wr_state;
logic [31:0] aw_addr_r;
logic [31:0] wd_r;
logic        aw_recv;
logic        w_recv;

assign tx_start = (wr_state == WR_EXEC) &&
                  (aw_addr_r[11:0] == UART_TX_DATA) && // The write address matches the UART transmit-data register
                  !tx_busy;
assign tx_data = wd_r[7:0];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_state  <= WR_IDLE;
        aw_addr_r <= '0;
        wd_r      <= '0;
        aw_recv   <= 1'b0;
        w_recv    <= 1'b0;
    end else begin
        case (wr_state)
            WR_IDLE: begin 
                if (s_awvalid && s_awready) begin
                    aw_addr_r <= s_awaddr;
                    aw_recv   <= 1'b1;
                end
                if (s_wvalid && s_wready) begin
                    wd_r    <= s_wdata;
                    w_recv  <= 1'b1;
                end
                if ((aw_recv || (s_awvalid && s_awready)) &&
                    (w_recv  || (s_wvalid  && s_wready))) begin
                    wr_state <= WR_EXEC;
                end
            end 

            WR_EXEC:begin 
                wr_state <= WR_RESP;
                aw_recv  <= 1'b0;
                w_recv   <= 1'b0;
            end 

            WR_RESP: begin 
                if (s_bvalid && s_bready) begin
                    wr_state <= WR_IDLE;
                end
            end 
            default :  wr_state <= WR_IDLE;
        endcase 
    end 
end 

assign s_awready = (wr_state == WR_IDLE) && !aw_recv;
assign s_wready  = (wr_state == WR_IDLE) && !w_recv;
assign s_bvalid  = (wr_state == WR_RESP);
assign s_bresp   = AXI_RESP_OKAY;


typedef enum logic [1:0] {
    RD_IDLE,
    RD_LATCH,
    RD_RESP
} rd_state_t;

rd_state_t  rd_state;
logic [31:0] rdata_r;
logic [31:0] ar_addr_r;

function automatic logic [31:0] reg_read(input logic [11:0] offset);
    case (offset)
        UART_TX_DATA: return 32'b0;          // write-only
        UART_STATUS:  return {31'b0, tx_busy}; // bit[0] = tx_busy
        default:      return 32'b0;
    endcase
endfunction

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_state  <= RD_IDLE;
        rdata_r   <= '0;
        ar_addr_r <= '0;
    end else begin
        case (rd_state)
            RD_IDLE: begin
                if (s_arvalid && s_arready) begin
                    ar_addr_r <= s_araddr;
                    rd_state  <= RD_LATCH;
                end
            end
            RD_LATCH: begin
                rdata_r  <= reg_read(ar_addr_r[11:0]);
                rd_state <= RD_RESP;
            end
            RD_RESP: begin
                if (s_rvalid && s_rready) begin
                    rd_state <= RD_IDLE;
                end
            end
            default: rd_state <= RD_IDLE;
        endcase 
    end 
end 

assign s_arready = (rd_state == RD_IDLE);
assign s_rvalid  = (rd_state == RD_RESP);
assign s_rdata   = rdata_r;
assign s_rresp   = AXI_RESP_OKAY;
// TODO : Add proper BRESP/RRESP logic when you write soc_top.sv and run the integration test. 
endmodule 
