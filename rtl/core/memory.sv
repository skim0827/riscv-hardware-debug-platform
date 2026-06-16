`timescale 1ns/1ps
// BRAM-backed memory with SECDED ECC.
// Uses Vivado bram_sp_39x512 IP: 39 bits by 512 entries.
module memory #(
    parameter WORDS    = 512,
    parameter mem_init = "",
    parameter IS_DMEM  = 0    // 1 → instantiates bram_sp_39x128_d (separate Vivado IP with DMEM COE)
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] a,
    input  logic [31:0] wd,
    input  logic        we,
    input  logic [2:0]  funct3,
    output logic [31:0] rd,
    output logic        corrected,
    output logic        detected
);

localparam bit [5:0] cw_pos[32] = '{
    6'd3,  6'd5,  6'd6,  6'd7,  6'd9,  6'd10, 6'd11, 6'd12,
    6'd13, 6'd14, 6'd15, 6'd17, 6'd18, 6'd19, 6'd20, 6'd21,
    6'd22, 6'd23, 6'd24, 6'd25, 6'd26, 6'd27, 6'd28, 6'd29,
    6'd30, 6'd31, 6'd33, 6'd34, 6'd35, 6'd36, 6'd37, 6'd38
};

function automatic [6:0] ecc_encode(input logic [31:0] data);
    logic [5:0] h;
    h = 6'b0;
    for (int i = 0; i < 32; i++)
        if (data[i]) h ^= cw_pos[i];
    return {(^data ^ ^h), h};
endfunction

// Write path for SB/SH/SW.
logic [31:0] rdata_bram;  
logic [6:0]  recc_bram;   

logic [31:0] merged_wd;
logic [38:0] bram_din;
logic [38:0] bram_dout;
logic [8:0]  addr;

assign addr = a[10:2];

always_comb begin
// Partial writes use the previous BRAM read data during bring-up.
    merged_wd = rdata_bram;
    case (funct3[1:0])
        2'b10: merged_wd = wd;
        2'b01: begin
            if (!a[1]) merged_wd[15:0]  = wd[15:0];
            else       merged_wd[31:16] = wd[15:0];
        end
        2'b00: begin
            case (a[1:0])
                2'b00: merged_wd[7:0]   = wd[7:0];
                2'b01: merged_wd[15:8]  = wd[7:0];
                2'b10: merged_wd[23:16] = wd[7:0];
                2'b11: merged_wd[31:24] = wd[7:0];
            endcase
        end
        default: merged_wd = wd;
    endcase
end

assign bram_din    = {ecc_encode(merged_wd), merged_wd};
assign rdata_bram  = bram_dout[31:0];
assign recc_bram   = bram_dout[38:32];

// Vivado single-port BRAM IP.
// IS_DMEM selects which IP to instantiate so each gets its own COE init file.
// MEM_INIT is sim-only; the real Vivado IPs have no such parameter.
generate
  if (IS_DMEM) begin : gen_bram
    `ifdef SIMULATION
    bram_sp_39x512_dmem #(.MEM_INIT(mem_init)) u_bram (
    `else
    bram_sp_39x512_dmem u_bram (
    `endif
        .clka(clk), .wea(we), .addra(addr), .dina(bram_din), .douta(bram_dout)
    );
  end else begin : gen_bram
    `ifdef SIMULATION
    bram_sp_39x512 #(.MEM_INIT(mem_init)) u_bram (
    `else
    bram_sp_39x512 u_bram (
    `endif
        .clka(clk), .wea(we), .addra(addr), .dina(bram_din), .douta(bram_dout)
    );
  end
endgenerate

// ECC decoding
logic [31:0] corrected_data;
logic _unused;
assign _unused = rst_n | |a[31:11];

always_comb begin : ecc_decode
    logic [5:0] h, syndrome;
    logic       overall_err;
    logic [31:0] data;

    data        = rdata_bram;
    h           = 6'b0;
    corrected   = 1'b0;
    detected    = 1'b0;

    for (int i = 0; i < 32; i++)
        if (data[i]) h ^= cw_pos[i];

    syndrome    = h ^ recc_bram[5:0];
    overall_err = ^data ^ ^recc_bram[5:0] ^ recc_bram[6];

    if (syndrome == 6'b0 && overall_err == 1'b0) begin
        corrected_data = data;
    end else if (syndrome != 6'b0 && overall_err == 1'b1) begin
        for (int i = 0; i < 32; i++)
            if (cw_pos[i] == syndrome) data = data ^ (32'b1 << i); // flip
        corrected_data = data;
        corrected      = 1'b1;
    end else if (syndrome != 6'b0 && overall_err == 1'b0) begin
        corrected_data = data;
        detected       = 1'b1;
    end else begin
        corrected_data = data;
    end
end

// Read path with funct3 sign/zero extension.
// a[1:0] byte offset (ignored for word access)
// a[10:2] word index.
always_comb begin 
    case(funct3)
        3'b000 : begin // LB
            case (a[1:0])
                2'b00 : rd = {{24{corrected_data[7]}},  corrected_data[7:0]};
                2'b01 : rd = {{24{corrected_data[15]}}, corrected_data[15:8]};
                2'b10 : rd = {{24{corrected_data[23]}}, corrected_data[23:16]};
                2'b11 : rd = {{24{corrected_data[31]}}, corrected_data[31:24]};
            endcase
        end
        3'b001 : begin // LH
            if (!a[1]) rd = {{16{corrected_data[15]}}, corrected_data[15:0]};
            else       rd = {{16{corrected_data[31]}}, corrected_data[31:16]};
        end
        3'b100 : begin // LBU 
            case (a[1:0])
                2'b00 : rd = {24'b0, corrected_data[7:0]};
                2'b01 : rd = {24'b0, corrected_data[15:8]};
                2'b10 : rd = {24'b0, corrected_data[23:16]};
                2'b11 : rd = {24'b0, corrected_data[31:24]};
            endcase
        end
        3'b101 : begin // LHU
            if (!a[1]) rd = {16'b0, corrected_data[15:0]};
            else       rd = {16'b0, corrected_data[31:16]};
        end
        default : rd = corrected_data; // LW
    endcase 
end

endmodule
