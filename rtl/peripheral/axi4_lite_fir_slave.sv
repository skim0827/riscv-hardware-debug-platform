module axi4_lite_fir_slave (
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
    input  logic        s_rready
);
/*
| Address | Register   |
| ------- | ---------- |
| `0x000` | Control    |
| `0x004` | Data Out   |
| `0x008` | Status     |
| `0x00C` | Soft Reset |

*/
import axi4_lite_pkg::*;
// Internal FIR signals
logic signed [15:0] fir_data_in;
logic               fir_valid_in;
logic               fir_ready_out;   // always 1 from fir_filter
logic signed [15:0] fir_data_out;
logic               fir_valid_out;

logic        ctrl_srst;
logic        fir_rst_n;
assign fir_rst_n = rst_n & ~ctrl_srst;
/*
fir_valid_in   -> input sample is valid
fir_valid_out  -> FIR result is valid
out_valid      -> AXI wrapper has a result waiting for the CPU
*/

fir_filter u_fir (
    .clk      (clk),
    .rst_n    (fir_rst_n),
    .data_in  (fir_data_in),
    .valid_in (fir_valid_in),
    .ready_out(fir_ready_out),
    .data_out (fir_data_out),
    .valid_out(fir_valid_out)
);

// Output reg
logic signed [15:0] out_reg;
logic               out_valid;
logic               rd_clear_out_valid;  // 1-cycle pulse from read FSM
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_reg   <= '0;
        out_valid <= 1'b0;
    end else begin
        if (fir_valid_out) begin
            out_reg   <= fir_data_out;
            out_valid <= 1'b1;
        end else if (rd_clear_out_valid) begin
            out_valid <= 1'b0;
        end
    end
end


typedef enum logic [1:0] {
    WR_IDLE,
    WR_EXEC,
    WR_RESP
} wr_state_t;

wr_state_t   wr_state;
logic [11:0] aw_addr_r; // latched aw addr 
logic [31:0] wd_r;
logic        aw_recv;
logic        w_recv;
logic        fir_busy; 

assign fir_busy = (wr_state == WR_EXEC);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_state  <= WR_IDLE;
        aw_addr_r <= '0;
        wd_r      <= '0;
        aw_recv   <= 1'b0;
        w_recv    <= 1'b0;
        ctrl_srst <= 1'b0; // control sw reset 
        fir_data_in  <= '0;
        fir_valid_in <= 1'b0;
    end else begin
        fir_valid_in <= 1'b0;
        ctrl_srst    <= 1'b0;

        case (wr_state)
            WR_IDLE: begin
                if (s_awvalid && s_awready) begin
                    aw_addr_r <= s_awaddr[11:0];
                    aw_recv   <= 1'b1;
                end
                if (s_wvalid && s_wready) begin
                    wd_r    <= s_wdata;
                    w_recv  <= 1'b1;
                end
                if ((aw_recv || (s_awvalid && s_awready)) &&
                    (w_recv  || (s_wvalid  && s_wready)))
                    wr_state <= WR_EXEC;
            end

            WR_EXEC: begin
                aw_recv  <= 1'b0;
                w_recv   <= 1'b0;
                wr_state <= WR_RESP;

                case (aw_addr_r)
                    12'h000: begin   // DATA_IN — push sample to FIR
                        fir_data_in  <= signed'(wd_r[15:0]);
                        fir_valid_in <= 1'b1;
                    end
                    12'h00C: begin   // soft reset
                        ctrl_srst <= wd_r[0];
                    end
                    default: ;       // ignore writes to read-only registers
                endcase
            end

            WR_RESP: begin
                if (s_bready) wr_state <= WR_IDLE;
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
logic [11:0] ar_addr_r;
logic [31:0] rdata_r;


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_state  <= RD_IDLE;
        ar_addr_r <= '0;
        rdata_r   <= '0;
        rd_clear_out_valid <= 1'b0;
    end else begin
        rd_clear_out_valid <= 1'b0;
        case (rd_state)
            RD_IDLE: begin
                if (s_arvalid && s_arready) begin
                    ar_addr_r <= s_araddr[11:0];
                    rd_state  <= RD_LATCH;
                end
            end

            RD_LATCH: begin
                rd_state <= RD_RESP;
                case (ar_addr_r)
                    FIR_DATA_OUT: begin
                        rdata_r            <= {15'b0, out_valid, out_reg};
                        rd_clear_out_valid <= 1'b1;   // clear flag on read
                    end
                    FIR_STATUS: begin
                        rdata_r <= {30'b0, fir_busy, out_valid};
                    end
                    default: rdata_r <= 32'hDEAD_BEEF;
                endcase
            end


            RD_RESP: begin
                if (s_rready) rd_state <= RD_IDLE;
            end

            default: rd_state <= RD_IDLE;
        endcase
    end
end

assign s_arready = (rd_state == RD_IDLE);
assign s_rvalid  = (rd_state == RD_RESP);
assign s_rdata   = rdata_r;
assign s_rresp   = AXI_RESP_OKAY;

logic _unused;
assign _unused = |s_wstrb | fir_ready_out;
endmodule
