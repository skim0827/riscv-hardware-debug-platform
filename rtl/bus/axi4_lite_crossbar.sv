// TOPOLOGY
//
//                 CPU (one master)
//                      |
//          +-----------+-----------+
//          |     axi4_lite_crossbar |
//          +-----------+-----------+
//          |     |     |     |     |
//        IMEM  DMEM  UART  Timer Health

// Write address (AW) must arrive before write data (W). This is a common
// restriction in lightweight single-master designs. Full AXI4-Lite allows
// W to arrive first; we would need a skid buffer to handle that case, which
// adds complexity without teaching anything new here.
// All slave AW/AR ready signals are assumed combinatorially available.
// The slave wrappers we write next will always assert ready immediately,
// so this is safe. A production crossbar would add a register stage here
// to break the combinatorial path.
module axi4_lite_crossbar
    import axi4_lite_pkg::*;
(
    input logic clk,
    input logic rst_n,

    input  logic [31:0] m_awaddr,
    input  logic        m_awvalid,
    output logic        m_awready,

    input  logic [31:0] m_wdata,
    input  logic [3:0]  m_wstrb,   // byte enables: bit[i]=1 means byte i is valid
    input  logic        m_wvalid,
    output logic        m_wready,

    output logic [1:0]  m_bresp,
    output logic        m_bvalid,
    input  logic        m_bready,

    input  logic [31:0] m_araddr,
    input  logic        m_arvalid,
    output logic        m_arready,

    output logic [31:0] m_rdata,
    output logic [1:0]  m_rresp,
    output logic        m_rvalid,
    input  logic        m_rready,

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
    else                                           return NUM_SLAVES; // no match
endfunction


typedef enum logic [1:0] {
    WR_IDLE,
    WR_DATA,
    WR_RESP
} wr_state_t;

int wr_slv; 
logic wr_decerr; 

always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin 
        wr_state  <= WR_IDLE;
        wr_slv    <= 0;
        wr_decerr <= 1'b0;
    end else begin 
        case (wr_state)
            WR_IDLE: begin 
                wr_slv    <= decode_addr(m_awaddr);
                wr_decerr <= (decode_addr(m_awaddr) == NUM_SLAVES);
                wr_state  <= WR_DATA;
            end 

            WR_DATA: begin
                if (m_wvalid && m_wready) begin
                    wr_state <= WR_RESP;
                end
            end 

            WR_RESP: begin 
                if (m_bvalid && m_bready) begin
                    wr_state  <= WR_IDLE;
                    wr_decerr <= 1'b0;
                end
            end

            default : wr_state <= WR_IDLE;
        endcase
    end 
end


assign m_awready = (wr_state == WR_IDLE);
assign m_wready = (wr_state == WR_DATA) ?
                      (wr_decerr ? 1'b1 : s_wready[wr_slv]) : 1'b0;
assign m_bvalid = (wr_state == WR_RESP) ?
                      (wr_decerr ? 1'b1 : s_bvalid[wr_slv]) : 1'b0;
assign m_bresp  = (wr_state == WR_RESP) ?
                      (wr_decerr ? AXI_RESP_DECERR : s_bresp[wr_slv]) : AXI_RESP_OKAY;

typedef enum logic [1:0] {
    RD_IDLE,
    RD_WAIT
} rd_state_t;

rd_state_t rd_state;
int        rd_slv;
logic      rd_decerr;

always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin
        rd_state  <= RD_IDLE;
        rd_slv    <= 0;
        rd_decerr <= 1'b0;
    end else begin
        case (rd_state)
            RD_IDLE: begin 
                if (m_arvalid && m_arready) begin
                    rd_slv    <= decode_addr(m_araddr);
                    rd_decerr <= (decode_addr(m_araddr) == NUM_SLAVES);
                    rd_state  <= RD_WAIT;
                end
            end 

            RD_WAIT: begin
                if (m_rvalid && m_rready) begin
                    rd_state  <= RD_IDLE;
                    rd_decerr <= 1'b0;
                end
            end 
            default : rd_state <= RD_IDLE;
        endcase 
    end
end 

assign m_arready = (rd_state == RD_IDLE);
assign m_rvalid  = (rd_state == RD_WAIT) ?
                       (rd_decerr ? 1'b1 : s_rvalid[rd_slv]) : 1'b0;
assign m_rdata   = (rd_state == RD_WAIT) ?
                       (rd_decerr ? 32'hDEAD_BEEF : s_rdata[rd_slv]) : 32'b0;
assign m_rresp   = (rd_state == RD_WAIT) ?
                       (rd_decerr ? AXI_RESP_DECERR : s_rresp[rd_slv]) : AXI_RESP_OKAY;



always_comb begin
    for (int i = 0; i < NUM_SLAVES; i++) begin
        s_awaddr[i]  = m_awaddr;
        s_awvalid[i] = (wr_state == WR_IDLE) && m_awvalid && (decode_addr(m_awaddr) == i);

        s_wdata[i]   = m_wdata;
        s_wstrb[i]   = m_wstrb; // master write strobe
        s_wvalid[i]  = (wr_state == WR_DATA) && !wr_decerr && (wr_slv == i) && m_wvalid;

        s_bready[i]  = (wr_state == WR_RESP) && !wr_decerr && (wr_slv == i) && m_bready;

        s_araddr[i]  = m_araddr;
        s_arvalid[i] = (rd_state == RD_IDLE) && m_arvalid && (decode_addr(m_araddr) == i);

        s_rready[i]  = (rd_state == RD_WAIT) && !rd_decerr && (rd_slv == i) && m_rready;

    end 
end 


endmodule
