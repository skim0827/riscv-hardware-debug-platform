`timescale 1ns/1ps
module dma_ctrl
    import axi4_lite_pkg::*;
(
    input  logic clk,
    input  logic rst_n,

    // AXI4-Lite slave : CPU -> DMA
    input  logic [31:0] s_awaddr,
    input  logic        s_awvalid,
    output logic        s_awready,
    input  logic [31:0] s_wdata,
    input  logic [3:0]  s_wstrb,
    input  logic        s_wvalid,
    output logic        s_wready,
    output logic [1:0]  s_bresp,
    output logic        s_bvalid,
    input  logic        s_bready, // CPU
    input  logic [31:0] s_araddr,
    input  logic        s_arvalid,
    output logic        s_arready,
    output logic [31:0] s_rdata,
    output logic [1:0]  s_rresp,
    output logic        s_rvalid,
    input  logic        s_rready,

    // AXI4-Lite master DMA
    output logic [31:0] m_awaddr,
    output logic        m_awvalid,
    input  logic        m_awready,
    output logic [31:0] m_wdata,
    output logic [3:0]  m_wstrb,
    output logic        m_wvalid,
    input  logic        m_wready,
    input  logic [1:0]  m_bresp,
    input  logic        m_bvalid,
    output logic        m_bready,
    output logic [31:0] m_araddr,
    output logic        m_arvalid,
    input  logic        m_arready,
    input  logic [31:0] m_rdata,
    input  logic [1:0]  m_rresp,
    input  logic        m_rvalid,
    output logic        m_rready,

    output logic        dma_irq
);

localparam [11:0] REG_SRC_ADDR = 12'h000;
localparam [11:0] REG_DST_ADDR = 12'h004;
localparam [11:0] REG_LEN      = 12'h008;
localparam [11:0] REG_CTRL     = 12'h00C;
localparam [11:0] REG_STATUS   = 12'h010;

localparam [31:0] ADDR_FIR_DIN  = FIR_BASE + {{20{1'b0}}, FIR_DATA_IN};
localparam [31:0] ADDR_FIR_DOUT = FIR_BASE + {{20{1'b0}}, FIR_DATA_OUT};
localparam [31:0] ADDR_FIR_STAT = FIR_BASE + {{20{1'b0}}, FIR_STATUS};

logic [31:0] r_src_addr, r_dst_addr, r_len;
logic        r_irq_en;


// Status flags (set > clear priority)
logic s_done, s_error;
logic slv_clr_done, slv_clr_error;


// FSM
typedef enum logic [3:0] {
    ST_IDLE,
    ST_RD_SRC_AX, ST_RD_SRC_R,
    ST_WR_FIR_AW, ST_WR_FIR_W, ST_WR_FIR_B,
    ST_POLL_AX,   ST_POLL_R,
    ST_RD_FIR_AX, ST_RD_FIR_R,
    ST_WR_DST_AW, ST_WR_DST_W, ST_WR_DST_B,
    ST_DONE,
    ST_ERROR
} dma_state_t;

dma_state_t  state;
logic [31:0] cur_src, cur_dst, word_cnt;
logic [15:0] sample_r;

logic s_busy;
assign s_busy = (state != ST_IDLE) && (state != ST_DONE) && (state != ST_ERROR);


// Slave write FSM
typedef enum logic [1:0] { SWR_IDLE, SWR_EXEC, SWR_RESP } swr_state_t;
swr_state_t  swr_state;
logic [11:0] saw_addr_r;
logic [31:0] swd_r;
logic        saw_recv, sw_recv;
logic        cfg_start;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        swr_state     <= SWR_IDLE;
        saw_addr_r    <= '0;
        swd_r         <= '0;
        saw_recv      <= 1'b0;
        sw_recv       <= 1'b0;
        r_src_addr    <= '0;
        r_dst_addr    <= '0;
        r_len         <= '0;
        r_irq_en      <= 1'b0;
        cfg_start     <= 1'b0;
        slv_clr_done  <= 1'b0;
        slv_clr_error <= 1'b0;
    end else begin
        cfg_start     <= 1'b0;
        slv_clr_done  <= 1'b0;
        slv_clr_error <= 1'b0;

        case (swr_state)
            SWR_IDLE: begin
                if (s_awvalid && s_awready) begin
                    saw_addr_r <= s_awaddr[11:0];
                    saw_recv   <= 1'b1;
                end
                if (s_wvalid && s_wready) begin
                    swd_r   <= s_wdata;
                    sw_recv <= 1'b1;
                end
                if ((saw_recv || (s_awvalid && s_awready)) &&
                    (sw_recv  || (s_wvalid  && s_wready)))
                    swr_state <= SWR_EXEC;
            end

            SWR_EXEC: begin
                saw_recv  <= 1'b0;
                sw_recv   <= 1'b0;
                swr_state <= SWR_RESP;
                case (saw_addr_r)
                    REG_SRC_ADDR: r_src_addr <= swd_r;
                    REG_DST_ADDR: r_dst_addr <= swd_r;
                    REG_LEN:      r_len      <= swd_r;
                    REG_CTRL: begin
                        r_irq_en <= swd_r[1];
                        if (swd_r[0] && !s_busy) cfg_start <= 1'b1;
                    end
                    REG_STATUS: begin
                        slv_clr_done  <= swd_r[1];
                        slv_clr_error <= swd_r[2];
                    end
                    default: ;
                endcase
            end

            SWR_RESP: if (s_bready) swr_state <= SWR_IDLE;
            default:  swr_state <= SWR_IDLE;
        endcase
    end
end

assign s_awready = (swr_state == SWR_IDLE) && !saw_recv;
assign s_wready  = (swr_state == SWR_IDLE) && !sw_recv;
assign s_bvalid  = (swr_state == SWR_RESP); // // DMA
assign s_bresp   = AXI_RESP_OKAY;


// Slave read FSM
typedef enum logic [1:0] { SRD_IDLE, SRD_LATCH, SRD_RESP } srd_state_t;
srd_state_t  srd_state;
logic [11:0] sar_addr_r;
logic [31:0] srd_rdata_r;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        srd_state   <= SRD_IDLE;
        sar_addr_r  <= '0;
        srd_rdata_r <= '0;
    end else begin
        case (srd_state)
            SRD_IDLE: begin
                if (s_arvalid && s_arready) begin
                    sar_addr_r <= s_araddr[11:0];
                    srd_state  <= SRD_LATCH;
                end
            end

            SRD_LATCH: begin
                srd_state <= SRD_RESP;
                case (sar_addr_r)
                    REG_SRC_ADDR: srd_rdata_r <= r_src_addr;
                    REG_DST_ADDR: srd_rdata_r <= r_dst_addr;
                    REG_LEN:      srd_rdata_r <= r_len;
                    REG_CTRL:     srd_rdata_r <= {30'b0, r_irq_en, 1'b0};
                    REG_STATUS:   srd_rdata_r <= {29'b0, s_error, s_done, s_busy};
                    default:      srd_rdata_r <= 32'hDEAD_BEEF;
                endcase
            end

            SRD_RESP: if (s_rready) srd_state <= SRD_IDLE;
            default:  srd_state <= SRD_IDLE;
        endcase
    end
end

assign s_arready = (srd_state == SRD_IDLE);
assign s_rvalid  = (srd_state == SRD_RESP);
assign s_rdata   = srd_rdata_r;
assign s_rresp   = AXI_RESP_OKAY;


// Status bits — set by main FSM, cleared by CPU W1C; set wins
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s_done  <= 1'b0;
        s_error <= 1'b0;
    end else begin
        s_done  <= (state == ST_DONE)  ? 1'b1 :
                   slv_clr_done        ? 1'b0 : s_done;
        s_error <= (state == ST_ERROR) ? 1'b1 :
                   slv_clr_error       ? 1'b0 : s_error;
    end
end


// Main DMA engine
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state    <= ST_IDLE;
        cur_src  <= '0;
        cur_dst  <= '0;
        word_cnt <= '0;
        sample_r <= '0;
        m_araddr  <= '0; m_arvalid <= 1'b0; m_rready  <= 1'b0;
        m_awaddr  <= '0; m_awvalid <= 1'b0;
        m_wdata   <= '0; m_wstrb   <= '0;   m_wvalid  <= 1'b0;
        m_bready  <= 1'b0;
    end else begin
        case (state)

            ST_IDLE: begin
                if (cfg_start && (r_len != '0)) begin
                    cur_src  <= r_src_addr;
                    cur_dst  <= r_dst_addr;
                    word_cnt <= '0;
                    state    <= ST_RD_SRC_AX;
                end
            end

            // read input sample from DMEM

            ST_RD_SRC_AX: begin
                m_araddr  <= cur_src;
                m_arvalid <= 1'b1;
                if (m_arready) begin
                    m_arvalid <= 1'b0;
                    m_rready  <= 1'b1;
                    state     <= ST_RD_SRC_R;
                end
            end

            ST_RD_SRC_R: begin
                if (m_rvalid) begin
                    m_rready <= 1'b0;
                    if (m_rresp != AXI_RESP_OKAY) state <= ST_ERROR;
                    else begin
                        sample_r <= m_rdata[15:0];
                        state    <= ST_WR_FIR_AW;
                    end
                end
            end

            // write sample to FIR DATA_IN

            ST_WR_FIR_AW: begin
                m_awaddr  <= ADDR_FIR_DIN;
                m_awvalid <= 1'b1;
                if (m_awready) begin
                    m_awvalid <= 1'b0;
                    state     <= ST_WR_FIR_W;
                end
            end

            ST_WR_FIR_W: begin
                m_wdata  <= {16'b0, sample_r};
                m_wstrb  <= 4'hF;
                m_wvalid <= 1'b1;
                if (m_wready) begin
                    m_wvalid <= 1'b0;
                    m_bready <= 1'b1;
                    state    <= ST_WR_FIR_B;
                end
            end

            ST_WR_FIR_B: begin
                if (m_bvalid) begin
                    m_bready <= 1'b0;
                    if (m_bresp != AXI_RESP_OKAY) state <= ST_ERROR;
                    else                           state <= ST_POLL_AX;
                end
            end

            // poll FIR STATUS until out_valid (bit 0) is set

            ST_POLL_AX: begin
                m_araddr  <= ADDR_FIR_STAT;
                m_arvalid <= 1'b1;
                if (m_arready) begin
                    m_arvalid <= 1'b0;
                    m_rready  <= 1'b1;
                    state     <= ST_POLL_R;
                end
            end

            ST_POLL_R: begin
                if (m_rvalid) begin
                    m_rready <= 1'b0;
                    if (m_rresp != AXI_RESP_OKAY) state <= ST_ERROR;
                    else if (m_rdata[0])           state <= ST_RD_FIR_AX;
                    else                           state <= ST_POLL_AX;
                end
            end

            // read FIR DATA_OUT

            ST_RD_FIR_AX: begin
                m_araddr  <= ADDR_FIR_DOUT;
                m_arvalid <= 1'b1;
                if (m_arready) begin
                    m_arvalid <= 1'b0;
                    m_rready  <= 1'b1;
                    state     <= ST_RD_FIR_R;
                end
            end

            ST_RD_FIR_R: begin
                if (m_rvalid) begin
                    m_rready <= 1'b0;
                    if (m_rresp != AXI_RESP_OKAY) state <= ST_ERROR;
                    else begin
                        sample_r <= m_rdata[15:0];
                        state    <= ST_WR_DST_AW;
                    end
                end
            end

            // write filtered result to DMEM

            ST_WR_DST_AW: begin
                m_awaddr  <= cur_dst;
                m_awvalid <= 1'b1;
                if (m_awready) begin
                    m_awvalid <= 1'b0;
                    state     <= ST_WR_DST_W;
                end
            end

            ST_WR_DST_W: begin
                m_wdata  <= {16'b0, sample_r};
                m_wstrb  <= 4'hF;
                m_wvalid <= 1'b1;
                if (m_wready) begin
                    m_wvalid <= 1'b0;
                    m_bready <= 1'b1;
                    state    <= ST_WR_DST_B;
                end
            end

            ST_WR_DST_B: begin
                if (m_bvalid) begin
                    m_bready <= 1'b0;
                    if (m_bresp != AXI_RESP_OKAY) begin
                        state <= ST_ERROR;
                    end else if (word_cnt == r_len - 32'd1) begin
                        state <= ST_DONE;
                    end else begin
                        cur_src  <= cur_src  + 32'd4;
                        cur_dst  <= cur_dst  + 32'd4;
                        word_cnt <= word_cnt + 32'd1;
                        state    <= ST_RD_SRC_AX;
                    end
                end
            end

            ST_DONE:  state <= ST_IDLE;
            ST_ERROR: state <= ST_IDLE;
            default:  state <= ST_IDLE;

        endcase
    end
end

// Level-triggered interrupt: stays asserted until CPU clears STATUS[1]
assign dma_irq = r_irq_en & s_done;

logic _unused;
assign _unused = |s_wstrb;

endmodule
