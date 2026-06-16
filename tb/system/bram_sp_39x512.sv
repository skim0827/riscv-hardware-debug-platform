`timescale 1ns/1ps
// bram_sp_39x512.sv — Simulation model for Vivado Block Memory Generator IP (512-deep)

module bram_sp_39x512 #(
    parameter MEM_INIT = ""
)(
    input  logic        clka,
    input  logic        wea,
    input  logic [8:0]  addra,
    input  logic [38:0] dina,
    output logic [38:0] douta
);

logic [38:0] mem [0:511];

localparam bit [5:0] CW_POS [32] = '{
    6'd3,  6'd5,  6'd6,  6'd7,  6'd9,  6'd10, 6'd11, 6'd12,
    6'd13, 6'd14, 6'd15, 6'd17, 6'd18, 6'd19, 6'd20, 6'd21,
    6'd22, 6'd23, 6'd24, 6'd25, 6'd26, 6'd27, 6'd28, 6'd29,
    6'd30, 6'd31, 6'd33, 6'd34, 6'd35, 6'd36, 6'd37, 6'd38
};

function automatic logic [6:0] ecc_encode(input logic [31:0] data);
    logic [5:0] h;
    h = 6'b0;
    for (int i = 0; i < 32; i++)
        if (data[i]) h ^= CW_POS[i];
    return {(^data ^ ^h), h};
endfunction

logic [31:0] raw_words [0:511];

initial begin
    for (int i = 0; i < 512; i++) mem[i] = 39'b0;

    if (MEM_INIT != "") begin
        $readmemh(MEM_INIT, raw_words);
        for (int i = 0; i < 512; i++)
            mem[i] = {ecc_encode(raw_words[i]), raw_words[i]};
        $display("[bram_sim] Loaded %s", MEM_INIT);
    end
end

always_ff @(posedge clka) begin
    if (wea) begin
        mem[addra] <= dina;
        douta      <= dina;
    end else begin
        douta <= mem[addra];
    end
end

endmodule
