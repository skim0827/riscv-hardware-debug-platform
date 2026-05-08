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

    output logic [31:0] rd
);

logic [31:0] mem [0:WORDS - 1];
logic [31:0] word; // byte addressed 0 - 3 bytes in one words 
assign word = mem[a[8:2]];

always_ff @(posedge clk) begin 
    if (rst_n == 0) begin
        for (int i = 0; i < WORDS; i++) mem[i] <= 32'b0;
    end else if (we) begin

        case (funct3[1:0])
            2'b10 : mem[a[8:2]] <= wd;
            2'b01 : begin 
                if (!a[1]) mem[a[8:2]][15:0] <= wd[15:0]; // SH 
                else mem[a[8:2]][31:16] <= wd[15:0];
            end 

            2'b00 : begin 
                case (a[1:0]) // SB 
                    2'b00 : mem[a[8:2]][7:0]   <= wd[7:0];
                    2'b01 : mem[a[8:2]][15:8]  <= wd[7:0];
                    2'b10 : mem[a[8:2]][23:16] <= wd[7:0];
                    2'b11 : mem[a[8:2]][31:24] <= wd[7:0];
                endcase 
            end 
            default : mem[a[8:2]] <= wd; // address is multiple of 4
        endcase 
    end 

end 

// a[1:0] byte offset (ignored for word access)
// a[8:2] word index (7 bits → 128 entries)

always_comb begin 
    case(funct3 )
        3'b000 : begin // LB
            case (a[1:0])
                2'b00 : rd = {{24{word[7]}},  word[7:0]};
                2'b01 : rd = {{24{word[15]}}, word[15:8]};
                2'b10 : rd = {{24{word[23]}}, word[23:16]};
                2'b11 : rd = {{24{word[31]}}, word[31:24]};
            endcase
        end
        3'b001 : begin // LH
            if (!a[1]) rd = {{16{word[15]}}, word[15:0]};
            else       rd = {{16{word[31]}}, word[31:16]};
        end
        3'b100 : begin // LBU
            case (a[1:0])
                2'b00 : rd = {24'b0, word[7:0]};
                2'b01 : rd = {24'b0, word[15:8]};
                2'b10 : rd = {24'b0, word[23:16]};
                2'b11 : rd = {24'b0, word[31:24]};
            endcase
        end
        3'b101 : begin // LHU
            if (!a[1]) rd = {16'b0, word[15:0]};
            else       rd = {16'b0, word[31:16]};
        end
        default : rd = word; // LW, and instruction fetch
    endcase 
end

endmodule 