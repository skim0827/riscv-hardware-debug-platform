// ============================================================================
// dmi_cdc_bridge.sv
//   tck domain  : JTAG test clock (DTM side, slow ~1-20 MHz)
//   clk domain  : system clock    (DM  side, fast ~50-200 MHz)
//
// Forward path  (tck → clk) : toggle synchronizer
//   - cmd_cap holds {we,re,addr,wdata} packed in tck domain
//   - toggle_tck flips whenever a new transaction arrives
//   - 3-stage pipeline (sync1→sync2→sync2_q) in clk domain detects the edge
//   - On edge: latch cmd_cap and pulse clk_dmi_valid for one clk cycle
//
//   Data safety assumption: tck ≪ clk, so cmd_cap is stable for many clk
//   cycles before the toggle edge propagates — standard "slow sender" CDC.
//
// Return path   (clk → tck) : 2-FF synchronizer
//   Safe for same reason: by the time tck samples, clk_dmi_rdata has been
//   stable for >> 1 tck period.
// ============================================================================
`timescale 1ns/1ps

module dmi_cdc_bridge (
    input  logic        tck,
    input  logic        clk,
    input  logic        rst_n,

    // TCK DOMAIN 
    input  logic [6:0]  tck_dmi_addr,
    input  logic [31:0] tck_dmi_wdata,
    input  logic        tck_dmi_we,
    input  logic        tck_dmi_re,
    output logic [31:0] tck_dmi_rdata,

    // CLK DOMAIN 
    output logic [6:0]  clk_dmi_addr, 
    output logic [31:0] clk_dmi_wdata, 
    output logic        clk_dmi_we, 
    output logic        clk_dmi_re, 
    output logic        clk_dmi_valid, // one-cycle pulse on new transaction
    input  logic [31:0] clk_dmi_rdata  
); 
// ============================================================================
// Forward path : tck → clk
// ============================================================================
logic [40:0] cmd_cap; // pack command bus
logic        toggle_tck;

always_ff @(posedge tck or negedge rst_n) begin 
    if (!rst_n) begin 
        cmd_cap    <= '0;
        toggle_tck <= 1'b0;
    end else if (tck_dmi_we || tck_dmi_re) begin
        cmd_cap  <= {tck_dmi_we, tck_dmi_re, tck_dmi_addr, tck_dmi_wdata};
        toggle_tck <= ~toggle_tck;
    end 
end 

logic sync1, sync2, sync2_q;

always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin 
        sync1    <= 1'b0;
        sync2    <= 1'b0;
        sync2_q  <= 1'b0;
        clk_dmi_addr  <= '0;
        clk_dmi_wdata <= '0;
        clk_dmi_we    <= 1'b0;
        clk_dmi_re    <= 1'b0;
        clk_dmi_valid <= 1'b0;
    end else begin
        sync1   <= toggle_tck;
        sync2   <= sync1;
        sync2_q <= sync2;

        clk_dmi_valid <= (sync2 != sync2_q); // Fires one cycle after sync2 changes — valid one-cycle pulse
        if (sync2 != sync2_q) begin
            {clk_dmi_we, clk_dmi_re, clk_dmi_addr, clk_dmi_wdata} <= cmd_cap;
        end else begin 
            clk_dmi_we <= 1'b0;
            clk_dmi_re <= 1'b0;
        end 
    end 
end 




// ============================================================================
// Return path : clk → tck  (2-FF synchroniser)
// ============================================================================
logic [31:0] rdata_sync1, rdata_sync2;

always_ff @(posedge tck or negedge rst_n) begin 
    if (!rst_n ) begin 
        rdata_sync1 <= '0;
        rdata_sync2 <= '0;
    end else begin
        rdata_sync1 <= clk_dmi_rdata;
        rdata_sync2 <= rdata_sync1;
    end 
end 

assign tck_dmi_rdata = rdata_sync2;

endmodule : dmi_cdc_bridge