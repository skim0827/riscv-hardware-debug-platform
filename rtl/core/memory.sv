`timescale 1ns/1ps
module memory #(
    parameter WORDS = 128, 
    parameter mem_init = ""
) (
    input clk,
    input rst_n, 

    input logic [31:0] a,
    input logic [31:0] wd, 
    input logic we,
    input logic [2:0] funct3,  

    output logic [31:0] rd, 
    output logic corrected,
    output logic detected
);

logic [38:0] mem [0:WORDS - 1];
logic [38:0] word; 
logic [31:0] corrected_data;
logic _unused_inputs;
assign word = mem[a[8:2]];
assign _unused_inputs = rst_n | |a[31:9];


localparam bit [5:0] cw_pos[32] = '{
    6'd3,  6'd5,  6'd6,  6'd7,  6'd9,  6'd10, 6'd11, 6'd12,
    6'd13, 6'd14, 6'd15, 6'd17, 6'd18, 6'd19, 6'd20, 6'd21,
    6'd22, 6'd23, 6'd24, 6'd25, 6'd26, 6'd27, 6'd28, 6'd29,
    6'd30, 6'd31, 6'd33, 6'd34, 6'd35, 6'd36, 6'd37, 6'd38
};

always_comb begin : ecc_decode
    logic [6:0] stored_ecc;
    logic [31:0] data;
    logic [5:0] h;
    logic stored_overall; 
    logic overall_err; 
    logic [5:0] syndrome;
    data = word[31:0];
    h = 6'b0;
    corrected = 1'b0;
    detected = 1'b0;
    stored_ecc = word[38:32];

    for (int i = 0; i < 32; i++) begin 
        if (data[i]) h ^= cw_pos[i];
    end

    stored_overall = stored_ecc[6];
    syndrome = h ^ (stored_ecc[5:0]); 
    overall_err = (^data ^ ^stored_ecc[5:0] ^ stored_overall);

    if (syndrome == 6'b0 && overall_err == 1'b0) begin 
        corrected_data = data;
    end else if (syndrome != 6'b0 && overall_err == 1'b1) begin
        for (int i=0; i < 32; i ++) begin 
            if (cw_pos[i] == syndrome) data = data ^ (32'b1 << i); // flip
        end 
        corrected_data = data;
        corrected = 1'b1; detected = 1'b0;
    end else if (syndrome != 6'b0 && overall_err == 1'b0) begin
        corrected_data = data;
        detected = 1'b1;
    end else corrected_data = data;
end 

function automatic [6:0] ecc_encode(input logic [31:0] data);
    logic [5:0] h;
    h = 6'b0;
    for (int i = 0; i < 32; i++)
        if (data[i]) h ^= cw_pos[i];
    return {(^data ^ ^h), h};
endfunction

function automatic logic [31:0] merge_write_data(
    input logic [31:0] old_word,
    input logic [31:0] write_data,
    input logic [1:0]  access_size,
    input logic [1:0]  byte_addr
);
    logic [31:0] merged;
    merged = old_word;
    case (access_size)
        2'b10: merged = write_data;
        2'b01: begin
            if (!byte_addr[1]) merged[15:0] = write_data[15:0];
            else               merged[31:16] = write_data[15:0];
        end
        2'b00: begin
            case (byte_addr)
                2'b00: merged[7:0]   = write_data[7:0];
                2'b01: merged[15:8]  = write_data[7:0];
                2'b10: merged[23:16] = write_data[7:0];
                2'b11: merged[31:24] = write_data[7:0];
            endcase
        end
        default: merged = write_data;
    endcase
    return merged;
endfunction

logic [31:0] raw [0:WORDS-1];

initial begin
    if (mem_init != "") begin
        $readmemh(mem_init, raw);
        for (int i = 0; i < WORDS; i++)
            mem[i] = {ecc_encode(raw[i]), raw[i]};
    end
end


always_ff @(posedge clk) begin 
    if (we) begin
        mem[a[8:2]] <= {
            ecc_encode(merge_write_data(word[31:0], wd, funct3[1:0], a[1:0])),
            merge_write_data(word[31:0], wd, funct3[1:0], a[1:0])
        };
    end 
end 

// a[1:0] byte offset (ignored for word access)
// a[8:2] word index (7 bits → 128 entries)

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
