// TOPOLOGY
//
//         CPU (M0)      DMA (M1)
//              \          /
//       +-------+--------+-------+
//       |   axi4_lite_crossbar   |
//       +--+--+--+--+--+--+--+--+
//          |  |  |  |  |  |  |
//        IMEM DMEM UART TMR HLT FIR DMA
//
// Arbitration: M0 (CPU) fixed priority over M1 (DMA).
// Write and read channels are arbitrated independently.

module axi4_lite_crossbar
    import axi4_lite_pkg::*;
(
    input logic clk,
    input logic rst_n,

    // Master 0: CPU
    input  logic [31:0] m0_awaddr,
    input  logic        m0_awvalid,
    output logic        m0_awready,
    input  logic [31:0] m0_wdata,
    input  logic [3:0]  m0_wstrb,
    input  logic        m0_wvalid,
    output logic        m0_wready,
    output logic [1:0]  m0_bresp,
    output logic        m0_bvalid,
    input  logic        m0_bready,
    input  logic [31:0] m0_araddr,
    input  logic        m0_arvalid,
    output logic        m0_arready,
    output logic [31:0] m0_rdata,
    output logic [1:0]  m0_rresp,
    output logic        m0_rvalid,
    input  logic        m0_rready,

    // Master 1: DMA
    input  logic [31:0] m1_awaddr,
    input  logic        m1_awvalid,
    output logic        m1_awready,
    input  logic [31:0] m1_wdata,
    input  logic [3:0]  m1_wstrb,
    input  logic        m1_wvalid,
    output logic        m1_wready,
    output logic [1:0]  m1_bresp,
    output logic        m1_bvalid,
    input  logic        m1_bready,
    input  logic [31:0] m1_araddr,
    input  logic        m1_arvalid,
    output logic        m1_arready,
    output logic [31:0] m1_rdata,
    output logic [1:0]  m1_rresp,
    output logic        m1_rvalid,
    input  logic        m1_rready,

    // Slave ports
    output logic [31:0] s_awaddr  [NUM_SLAVES],
    output logic        s_awvalid [NUM_SLAVES],
    input  logic        s_awready [NUM_SLAVES],

    output logic [31:0] s_wdata   [NUM_SLAVES],
    output logic [3:0]  s_wstrb   [NUM_SLAVES],
    output logic        s_wvalid  [NUM_SLAVES],
    input  logic        s_wready  [NUM_SLAVES],

    input  logic [1:0]  s_bresp   [NUM_SLAVES],
    input  logic        s_bvalid  [NUM_SLAVES],
    output logic        s_bready  [NUM_SLAVES],

    output logic [31:0] s_araddr  [NUM_SLAVES],
    output logic        s_arvalid [NUM_SLAVES],
    input  logic        s_arready [NUM_SLAVES],

    input  logic [31:0] s_rdata   [NUM_SLAVES],
    input  logic [1:0]  s_rresp   [NUM_SLAVES],
    input  logic        s_rvalid  [NUM_SLAVES],
    output logic        s_rready  [NUM_SLAVES]
);

function automatic int decode_addr(input logic [31:0] addr);
    if      ((addr & REGION_MASK) == IMEM_BASE)   return SLV_IMEM;
    else if ((addr & REGION_MASK) == DMEM_BASE)   return SLV_DMEM;
    else if ((addr & PAGE_MASK)   == UART_BASE)   return SLV_UART;
    else if ((addr & PAGE_MASK)   == TIMER_BASE)  return SLV_TIMER;
    else if ((addr & PAGE_MASK)   == HEALTH_BASE) return SLV_HEALTH;
    else if ((addr & PAGE_MASK)   == FIR_BASE)    return SLV_FIR;
    else if ((addr & PAGE_MASK)   == DMA_BASE)    return SLV_DMA;
    else                                           return NUM_SLAVES;
endfunction


// Write
typedef enum logic [1:0] { WR_IDLE, WR_DATA, WR_RESP } wr_state_t;
wr_state_t wr_state;
int        wr_slv;
logic      wr_decerr;
logic      wr_grant;  // 0 = M0 (CPU), 1 = M1 (DMA)

int wr_sel_m0, wr_sel_m1;
assign wr_sel_m0 = decode_addr(m0_awaddr);
assign wr_sel_m1 = decode_addr(m1_awaddr);

logic wr_slv_rdy_m0, wr_slv_rdy_m1;
assign wr_slv_rdy_m0 = (wr_sel_m0 == NUM_SLAVES) ? 1'b1 : s_awready[wr_sel_m0];
assign wr_slv_rdy_m1 = (wr_sel_m1 == NUM_SLAVES) ? 1'b1 : s_awready[wr_sel_m1];

assign m0_awready = (wr_state == WR_IDLE) &&  m0_awvalid && wr_slv_rdy_m0;
assign m1_awready = (wr_state == WR_IDLE) && !m0_awvalid && m1_awvalid && wr_slv_rdy_m1;

logic [31:0] act_wdata;
logic [3:0]  act_wstrb;
logic        act_wvalid;
logic        act_bready;

assign act_wdata  = wr_grant ? m1_wdata  : m0_wdata;
assign act_wstrb  = wr_grant ? m1_wstrb  : m0_wstrb;
assign act_wvalid = wr_grant ? m1_wvalid : m0_wvalid;
assign act_bready = wr_grant ? m1_bready : m0_bready;

logic       wr_slv_wready;
logic       wr_slv_bvalid;
logic [1:0] wr_slv_bresp;

assign wr_slv_wready = wr_decerr ? 1'b1        : s_wready[wr_slv];
assign wr_slv_bvalid = wr_decerr ? 1'b1        : s_bvalid[wr_slv];
assign wr_slv_bresp  = wr_decerr ? AXI_RESP_DECERR : s_bresp[wr_slv];

assign m0_wready = (!wr_grant) && (wr_state == WR_DATA) && wr_slv_wready;
assign m1_wready = ( wr_grant) && (wr_state == WR_DATA) && wr_slv_wready;

assign m0_bvalid = (!wr_grant) && (wr_state == WR_RESP) && wr_slv_bvalid;
assign m1_bvalid = ( wr_grant) && (wr_state == WR_RESP) && wr_slv_bvalid;

assign m0_bresp = (!wr_grant && (wr_state == WR_RESP)) ? wr_slv_bresp : AXI_RESP_OKAY;
assign m1_bresp = ( wr_grant && (wr_state == WR_RESP)) ? wr_slv_bresp : AXI_RESP_OKAY;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_state  <= WR_IDLE;
        wr_slv    <= 0;
        wr_decerr <= 1'b0;
        wr_grant  <= 1'b0;
    end else begin
        case (wr_state)
            WR_IDLE: begin
                if (m0_awvalid && m0_awready) begin
                    wr_slv    <= wr_sel_m0;
                    wr_decerr <= (wr_sel_m0 == NUM_SLAVES);
                    wr_grant  <= 1'b0;
                    wr_state  <= WR_DATA;
                end else if (m1_awvalid && m1_awready) begin
                    wr_slv    <= wr_sel_m1;
                    wr_decerr <= (wr_sel_m1 == NUM_SLAVES);
                    wr_grant  <= 1'b1;
                    wr_state  <= WR_DATA;
                end
            end
            WR_DATA: if (act_wvalid && wr_slv_wready) wr_state <= WR_RESP;
            WR_RESP: if (wr_slv_bvalid && act_bready) begin
                wr_state  <= WR_IDLE;
                wr_decerr <= 1'b0;
            end
            default: wr_state <= WR_IDLE;
        endcase
    end
end


// Read
typedef enum logic [1:0] { RD_IDLE, RD_WAIT } rd_state_t;
rd_state_t rd_state;
int        rd_slv;
logic      rd_decerr;
logic      rd_grant;  // 0 = M0 (CPU), 1 = M1 (DMA)

int rd_sel_m0, rd_sel_m1;
assign rd_sel_m0 = decode_addr(m0_araddr);
assign rd_sel_m1 = decode_addr(m1_araddr);

logic rd_slv_rdy_m0, rd_slv_rdy_m1;
assign rd_slv_rdy_m0 = (rd_sel_m0 == NUM_SLAVES) ? 1'b1 : s_arready[rd_sel_m0];
assign rd_slv_rdy_m1 = (rd_sel_m1 == NUM_SLAVES) ? 1'b1 : s_arready[rd_sel_m1];

assign m0_arready = (rd_state == RD_IDLE) &&  m0_arvalid && rd_slv_rdy_m0;
assign m1_arready = (rd_state == RD_IDLE) && !m0_arvalid && m1_arvalid && rd_slv_rdy_m1;

logic        act_rready;
logic        rd_slv_rvalid;
logic [31:0] rd_slv_rdata;
logic [1:0]  rd_slv_rresp;

assign act_rready   = rd_grant ? m1_rready : m0_rready;
assign rd_slv_rvalid = rd_decerr ? 1'b1             : s_rvalid[rd_slv];
assign rd_slv_rdata  = rd_decerr ? 32'hDEAD_BEEF    : s_rdata[rd_slv];
assign rd_slv_rresp  = rd_decerr ? AXI_RESP_DECERR  : s_rresp[rd_slv];

assign m0_rvalid = (!rd_grant) && (rd_state == RD_WAIT) && rd_slv_rvalid;
assign m1_rvalid = ( rd_grant) && (rd_state == RD_WAIT) && rd_slv_rvalid;

assign m0_rdata = (!rd_grant && (rd_state == RD_WAIT)) ? rd_slv_rdata : 32'b0;
assign m1_rdata = ( rd_grant && (rd_state == RD_WAIT)) ? rd_slv_rdata : 32'b0;

assign m0_rresp = (!rd_grant && (rd_state == RD_WAIT)) ? rd_slv_rresp : AXI_RESP_OKAY;
assign m1_rresp = ( rd_grant && (rd_state == RD_WAIT)) ? rd_slv_rresp : AXI_RESP_OKAY;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_state  <= RD_IDLE;
        rd_slv    <= 0;
        rd_decerr <= 1'b0;
        rd_grant  <= 1'b0;
    end else begin
        case (rd_state)
            RD_IDLE: begin
                if (m0_arvalid && m0_arready) begin
                    rd_slv    <= rd_sel_m0;
                    rd_decerr <= (rd_sel_m0 == NUM_SLAVES);
                    rd_grant  <= 1'b0;
                    rd_state  <= RD_WAIT;
                end else if (m1_arvalid && m1_arready) begin
                    rd_slv    <= rd_sel_m1;
                    rd_decerr <= (rd_sel_m1 == NUM_SLAVES);
                    rd_grant  <= 1'b1;
                    rd_state  <= RD_WAIT;
                end
            end
            RD_WAIT: if (rd_slv_rvalid && act_rready) rd_state <= RD_IDLE;
            default: rd_state <= RD_IDLE;
        endcase
    end
end


// Slave port routing
always_comb begin
    for (int i = 0; i < NUM_SLAVES; i++) begin
        s_awaddr[i]  = (wr_state == WR_IDLE && m0_awvalid) ? m0_awaddr : m1_awaddr;
        s_awvalid[i] = (wr_state == WR_IDLE) && (
                           m0_awvalid ? (wr_sel_m0 == i) :
                                        (m1_awvalid && (wr_sel_m1 == i)));

        s_wdata[i]   = act_wdata;
        s_wstrb[i]   = act_wstrb;
        s_wvalid[i]  = (wr_state == WR_DATA) && !wr_decerr && (wr_slv == i) && act_wvalid;

        s_bready[i]  = (wr_state == WR_RESP) && !wr_decerr && (wr_slv == i) && act_bready;

        s_araddr[i]  = (rd_state == RD_IDLE && m0_arvalid) ? m0_araddr : m1_araddr;
        s_arvalid[i] = (rd_state == RD_IDLE) && (
                           m0_arvalid ? (rd_sel_m0 == i) :
                                        (m1_arvalid && (rd_sel_m1 == i)));

        s_rready[i]  = (rd_state == RD_WAIT) && !rd_decerr && (rd_slv == i) && act_rready;
    end
end

endmodule
