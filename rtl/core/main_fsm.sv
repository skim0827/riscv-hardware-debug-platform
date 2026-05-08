`timescale 1ns/1ps
module main_fsm 
import riscv_pkg::*;
(
    input  logic clk, 
    input  logic rst_n,
    input  opcode_t op,
    

    // hart interface (from DM)
    input  logic hart_halt_req,
    input  logic hart_resume_req,
    output logic hart_halted, 


    // progbuf interface
    input  logic progbuf_exec,
    output logic progbuf_done,


    output logic Branch, 
    output logic PCUpdate,
    output logic RegWrite,
    output logic MemWrite, 
    output logic IRWrite, 

    output logic [1:0] ResultSrc, 
    output logic [1:0] ALUSrcB,
    output logic [1:0] ALUSrcA, 
    output logic       AdrSrc,
    output logic       ForceAdd
);


state_t state, next_state ; 

logic progbuf_active;

// ============================================================================
// State register + progbuf bookkeeping
// ============================================================================
always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin
        state          <= S_FETCH;
        progbuf_active <= 1'b0;
        progbuf_done   <= 1'b0;

    end else if (hart_halt_req) begin 
        state          <= S_HALTED;
        progbuf_active <= 1'b0;
        progbuf_done   <= 1'b0;
    end else if (hart_resume_req) begin 
        state          <= S_FETCH;
        progbuf_active <= 1'b0;
        progbuf_done   <= 1'b0;
    end else begin 
        state <= next_state;
        if (state == S_HALTED && progbuf_exec) progbuf_active <= 1; 
        else if (progbuf_active && next_state == S_HALTED) progbuf_active <= 0;
        progbuf_done <= progbuf_active && (next_state == S_HALTED);

    end 
end 

// ============================================================================
// Next-state / output logic
// ============================================================================
always_comb begin 
    next_state = state; 
    // DEFAULT VALUES 
    PCUpdate  = 1'b0;
    Branch    = 1'b0;

    ALUSrcA   = 2'b00;
    ALUSrcB   = 2'b00;

    ResultSrc = 2'b00;
    AdrSrc    = 1'b0;
    MemWrite  = 1'b0;
    RegWrite  = 1'b0;
    IRWrite   = 1'b0;

    hart_halted = (state == S_HALTED);
    ForceAdd = 0;
    

    case (state)  

        S_FETCH : begin 

            ALUSrcA = 2'b00;    // from PC 
            ALUSrcB = 2'b10;    // 4 
            ForceAdd = 1;       // always ADD for PC+4
            ResultSrc = 2'b10;  // alu result 
            PCUpdate = 1'b1;    // force pc write high 
            IRWrite = 1'b1;

            next_state = S_DECODE;
        end 

        S_DECODE : begin 
            ForceAdd = 1; // always ADD in decode stage : oldPC + Imm
            case (op)                  
                OPCODE_I_TYPE_LOAD : next_state = S_MEMADR;
                OPCODE_S_TYPE      : next_state = S_MEMADR;
                OPCODE_R_TYPE      : next_state = S_EXECUTER;
                OPCODE_I_TYPE_ALU  : next_state = S_EXECUTEI;

                OPCODE_B_TYPE : begin 
                    ALUSrcA = 2'b01;
                    ALUSrcB = 2'b01;

                    next_state = S_BRANCH;
                end 

                OPCODE_I_TYPE_JALR : begin 
                    ALUSrcA = 2'b01;
                    ALUSrcB = 2'b10;

                    next_state = S_JALR;
                end 

                OPCODE_U_TYPE_LUI : next_state = S_LUI;

                OPCODE_U_TYPE_AUIPC : next_state = S_AUIPC; 
                OPCODE_J_TYPE : begin 
                    ALUSrcA    = 2'b01; 
                    ALUSrcB    = 2'b01;
                    next_state = S_JAL;
                end 
                default next_state = S_FETCH;
            endcase
        end 

        S_MEMADR : begin 
            ALUSrcA = 2'b10 ;
            ALUSrcB = 2'b01 ; 

            next_state = (op == OPCODE_I_TYPE_LOAD) ? S_MEMREAD : S_MEMWRITE;
        end 

        S_MEMREAD : begin 
            ResultSrc = 2'b00;
            AdrSrc = 1'b1; 
            next_state = S_MEMWB;
            
        end 

        S_MEMWB : begin 
            ResultSrc  = 2'b01; 
            RegWrite   = 1'b1;
            next_state = progbuf_active ? S_HALTED : S_FETCH;
        end 

        S_MEMWRITE : begin 
            ResultSrc  = 2'b00; 
            AdrSrc     = 1'b1; 
            MemWrite   = 1'b1;
            next_state = progbuf_active ? S_HALTED : S_FETCH;
        end 

        S_EXECUTER : begin 
            ALUSrcA    = 2'b10;
            ALUSrcB    = 2'b00;

            next_state = S_ALUWB;
        end 

        S_EXECUTEI : begin 
            ALUSrcA    = 2'b10;
            ALUSrcB    = 2'b01;

            next_state = S_ALUWB;
        end 

        S_ALUWB : begin 
            ResultSrc  =  2'b00; 
            RegWrite   = 1'b1;
            
            next_state = progbuf_active ? S_HALTED : S_FETCH;
        end 

        S_JAL : begin 
            ALUSrcA    = 2'b01; // OldPC
            ALUSrcB    = 2'b10; // 4

            ResultSrc  = 2'b00;
            PCUpdate   = 1'b1;
            next_state = S_ALUWB;
        end 

        S_BRANCH : begin
            ALUSrcA    = 2'b10; 
            ALUSrcB    = 2'b00;

            ResultSrc  = 2'b00; 
            Branch     = 1'b1;
            next_state = progbuf_active ? S_HALTED : S_FETCH;
        end 


        S_JALR : begin 
            ALUSrcA = 2'b10; 
            ALUSrcB = 2'b01; 

            ResultSrc  = 2'b10; // combinational ALUResult = rs1+imm
            PCUpdate   = 1'b1;
            next_state = S_JALR_WB; // writes ALUOut=OldPC+4 to rd
        end 

        S_JALR_WB : begin 
            ALUSrcA = 2'b01; 
            ALUSrcB = 2'b10; 
            ForceAdd = 1'b1; // OldPC + 4 
            ResultSrc = 2'b10; // combinatorial OldPC + 4 = rd 
            RegWrite = 1'b1;
            next_state = progbuf_active ? S_HALTED : S_FETCH;
        end 
 

        S_LUI : begin 
            ALUSrcA = 2'b11; // 32'b0 
            ALUSrcB = 2'b01;

            ResultSrc = 2'b10;
            RegWrite = 1'b1;
            next_state = progbuf_active ? S_HALTED : S_FETCH;

        end 

        S_AUIPC : begin 
            ALUSrcA = 2'b01; // OldPC  
            ALUSrcB = 2'b01; 

            ResultSrc = 2'b10; 
            RegWrite = 1'b1;

            next_state = progbuf_active ? S_HALTED : S_FETCH;

        end 

        S_HALTED : begin 
            hart_halted = 1'b1; 
            if (progbuf_exec) next_state = S_DECODE;
        end 
        default : next_state = S_FETCH;
    endcase
end 

endmodule 