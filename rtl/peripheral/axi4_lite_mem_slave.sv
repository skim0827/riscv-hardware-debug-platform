`timescale 1ns/1ps
// WSTRB maps to word, halfword, or byte access size.

module axi4_lite_mem_slave #(
    parameter WORDS    = 128,
    parameter MEM_INIT = ""
)(
    input logic clk,
    input logic rst_n,

    // Write address
    input  logic [31:0] s_awaddr,
    input  logic        s_awvalid,
    output logic        s_awready,

    // Write data
    input  logic [31:0] s_wdata,
    input  logic [3:0]  s_wstrb,
    input  logic        s_wvalid,
    output logic        s_wready,

    // Write response
    output logic [1:0]  s_bresp,
    output logic        s_bvalid,
    input  logic        s_bready,

    // Read address
    input  logic [31:0] s_araddr,
    input  logic        s_arvalid,
    output logic        s_arready,

    // Read data
    output logic [31:0] s_rdata,
    output logic [1:0]  s_rresp,
    output logic        s_rvalid,
    input  logic        s_rready,

    // ECC telemetry 
    output logic corrected,
    output logic detected
);

import axi4_lite_pkg::*;

typedef enum logic [2:0] {
    WR_IDLE,    // waiting for AW and/or W
    WR_EXEC,    // both received, driving memory write port this cycle
    WR_RESP,    // waiting for master to accept B response
    WR_DONE     // one-cycle cleanup before returning to IDLE
} wr_state_t;

wr_state_t  wr_state;

// AXI can send the write address and write data in different cycles
logic [31:0] aw_addr_r;   // registered write address
logic [31:0] ar_addr_r;
logic [31:0] wd_r;        // registered write data
logic [3:0]  wstrb_r;     // registered write strobes
logic        aw_recv;     // address has been received
logic        w_recv;      // data has been received

always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin
        wr_state <= WR_IDLE;
        aw_recv  <= 1'b0;
        w_recv   <= 1'b0;
        aw_addr_r <= '0;
        wd_r      <= '0;
        wstrb_r   <= '0;
    end else begin 
        case (wr_state)
            WR_IDLE : begin 
                if (s_awvalid && s_awready) begin
                    aw_addr_r <= s_awaddr;
                    aw_recv   <= 1'b1;
                end
                if (s_wvalid && s_wready) begin
                    wd_r    <= s_wdata;
                    wstrb_r <= s_wstrb;
                    w_recv  <= 1'b1;
                end
                // available, either:
                // already saved it earlier: aw_recv
                // or it is arriving right now: s_awvalid && s_awready
                if ((aw_recv || (s_awvalid && s_awready)) &&
                    (w_recv  || (s_wvalid  && s_wready))) begin
                    wr_state <= WR_EXEC;
                end
            end 

            WR_EXEC : begin 
                wr_state <= WR_RESP;
                aw_recv  <= 1'b0;
                w_recv   <= 1'b0;
            end

            WR_RESP : begin 
                if (s_bvalid && s_bready) begin
                    wr_state <= WR_IDLE;
                end
            end 

            default : wr_state <= WR_IDLE;
        endcase 
    end 
end 
assign s_awready = (wr_state == WR_IDLE) && !aw_recv;
assign s_wready  = (wr_state == WR_IDLE) && !w_recv;

assign s_bvalid = (wr_state == WR_RESP);
assign s_bresp  = AXI_RESP_OKAY;

typedef enum logic [1:0] {
    RD_IDLE,
    RD_ADDR, // Send address to BRAM.
    RD_LATCH,   // address accepted, data coming out of memory this cycle
    RD_RESP     
} rd_state_t;

rd_state_t  rd_state;
logic [31:0] rdata_r;

always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin
        rd_state <= RD_IDLE;
        rdata_r  <= '0;
    end else begin 
        case (rd_state)
            RD_IDLE: begin 
                if (s_arvalid && s_arready) begin
                    ar_addr_r <= s_araddr;
                    rd_state <= RD_ADDR;
                end
            end 
            RD_ADDR: begin
                rd_state <= RD_LATCH;      // Wait one cycle for BRAM data.
            end
            RD_LATCH: begin 
                rdata_r  <= mem_rd;
                rd_state <= RD_RESP;
            end 

            RD_RESP: begin 
                if (s_rvalid && s_rready) begin
                    rd_state <= RD_IDLE;
                end
            end 

            default : rd_state <= RD_IDLE;
        endcase 
    end 
end 

assign s_arready = (rd_state == RD_IDLE);
assign s_rvalid  = (rd_state == RD_RESP);
assign s_rdata   = rdata_r;
assign s_rresp   = AXI_RESP_OKAY;

function automatic logic [2:0] wstrb_to_funct3(input logic [3:0] wstrb);
    case (wstrb)
        4'b1111:                          return 3'b010; // SW word
        4'b0011, 4'b1100:                 return 3'b001; // SH halfword
        4'b0001, 4'b0010, 4'b0100, 4'b1000: return 3'b000; // SB byte
        default:                          return 3'b010; // fallback: word
    endcase
endfunction


logic [31:0] mem_addr;
logic [31:0] mem_wd;
logic        mem_we;
logic [2:0]  mem_funct3;
logic [31:0] mem_rd;


assign mem_addr = (wr_state == WR_EXEC) ? aw_addr_r : ar_addr_r;
assign mem_wd     = wd_r;
assign mem_we     = (wr_state == WR_EXEC);
assign mem_funct3 = (wr_state == WR_EXEC) ? wstrb_to_funct3(wstrb_r) : 3'b010;
memory #(
    .WORDS   (WORDS),
    .mem_init(MEM_INIT)
) u_mem (
    .clk      (clk),
    .rst_n    (rst_n),
    .a        (mem_addr),
    .wd       (mem_wd),
    .we       (mem_we),
    .funct3   (mem_funct3),
    .rd       (mem_rd),
    .corrected(corrected),
    .detected (detected)
);
endmodule
