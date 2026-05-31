// REGISTER MAP (offsets from TIMER_BASE = 0x2000_1000)
//
//   Offset   Name      Access   Description
//   0x000    CTRL      R/W      bit[0]=timer_en, bit[1]=wdt_en,
//                               bit[2]=wdt_kick (self-clearing after one cycle)
//   0x004    COUNT     R        current timer counter (read-only)
//   0x008    TIMEOUT   R/W      threshold value for both timer and WDT
//   0x00C    STATUS    R/W1C    bit[0]=timer_irq_pending, bit[1]=wdt_fired
//                               write 1 to bit[0] to clear timer_irq_pending
//                               wdt_fired clears only on hard reset
`timescale 1ns/1ps
module axi4_lite_timer_slave (
    input  logic clk,
    input  logic rst_n,

    // AXI4-Lite slave port
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

    // Outputs to system
    output logic        timer_irq,
    output logic        wdt_reset
);

import axi4_lite_pkg::*;

logic [31:0] ctrl_reg;
logic [31:0] timeout_reg;
logic        irq_clear; // Software wrote a 1 to the STATUS interrupt bit, so clear the pending timer interrupt.

logic [31:0] count_wire;
logic [31:0] status_wire;

timer_wdt u_timer (
    .clk        (clk),
    .rst_n      (rst_n),
    .ctrl_i     (ctrl_reg),
    .count_o    (count_wire),
    .timeout_i  (timeout_reg),
    .status_o   (status_wire),
    .irq_clear_i(irq_clear),
    .timer_irq  (timer_irq),
    .wdt_reset  (wdt_reset)
);


typedef enum logic [1:0] {
    WR_IDLE,
    WR_EXEC,
    WR_RESP
} wr_state_t;


wr_state_t   wr_state;
logic [31:0] aw_addr_r;
logic [31:0] wd_r;
logic        aw_recv;
logic        w_recv;

assign irq_clear = (wr_state == WR_EXEC) &&
                   (aw_addr_r[11:0]== TIMER_STATUS) &&
                   wd_r[0]; // software wrote a 1 to STATUS bit 0

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_state   <= WR_IDLE;
        aw_addr_r  <= '0;
        wd_r       <= '0;
        aw_recv    <= 1'b0;
        w_recv     <= 1'b0;
        ctrl_reg   <= '0;
        timeout_reg<= '0;
    end else begin
        if (ctrl_reg[2]) ctrl_reg[2] <= 1'b0; // wdt_kick

        case (wr_state)
            WR_IDLE: begin
                if (s_awvalid && s_awready) begin
                    aw_addr_r <= s_awaddr;
                    aw_recv   <= 1'b1;
                end
                if (s_wvalid && s_wready) begin
                    wd_r   <= s_wdata;
                    w_recv <= 1'b1;
                end
                if ((aw_recv || (s_awvalid && s_awready)) &&
                    (w_recv  || (s_wvalid  && s_wready)))
                    wr_state <= WR_EXEC;
            end

            WR_EXEC: begin
                case (aw_addr_r[11:0])
                    TIMER_CTRL:    ctrl_reg    <= wd_r;
                    TIMER_TIMEOUT: timeout_reg <= wd_r;
                    TIMER_STATUS:  ; // W1C 
                    default: ;       // unknown offset ignored
                endcase
                wr_state <= WR_RESP;
                aw_recv  <= 1'b0;
                w_recv   <= 1'b0;
            end

            WR_RESP: begin
                if (s_bvalid && s_bready)
                    wr_state <= WR_IDLE;
            end

            default: wr_state <= WR_IDLE;
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

rd_state_t   rd_state;
logic [31:0] rdata_r;
logic [31:0] ar_addr_r;

function automatic logic [31:0] reg_read(input logic [11:0] offset);
    case (offset)
        TIMER_CTRL:    return ctrl_reg;
        TIMER_COUNT:   return count_wire;
        TIMER_TIMEOUT: return timeout_reg;
        TIMER_STATUS:  return status_wire;
        default:       return 32'b0;
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
                if (s_rvalid && s_rready)
                    rd_state <= RD_IDLE;
            end
            default: rd_state <= RD_IDLE;
        endcase
    end
end

assign s_arready = (rd_state == RD_IDLE);
assign s_rvalid  = (rd_state == RD_RESP);
assign s_rdata   = rdata_r;
assign s_rresp   = AXI_RESP_OKAY;

endmodule
