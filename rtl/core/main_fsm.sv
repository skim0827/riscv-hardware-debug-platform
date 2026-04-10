`timescale 1ns/1ps
module main_fsm (
    input  logic clk, 
    input  logic rst_n,
    input  opcode_t op,
    

    // hart interface (from DM)
    input  logic hart_halt_req,
    input  logic hart_resume_req,
    output logic hart_halted, // status 

    output logic Branch, 
    output logic PCUpdate,
    output logic RegWrite,
    output logic MemWrite, 
    output logic IRWrite, 

    output logic [1:0] ResultSrc, 
    output logic [1:0] ALUSrcB,
    output logic [1:0] ALUSrcA, 
    output logic       AdrSrc,
    output logic [1:0] ALUOp
);

import riscv_pkg::*;
state_t state, next_state ; 

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= S_FETCH;
    else if (hart_halt_req)
        state <= S_HALTED;
    else if (hart_resume_req)
        state <= S_FETCH;
    else
        state <= next_state;
end 

always_comb begin 
    next_state = state; 
    // DEFAULT VALUES 
    PCUpdate  = 1'b0;
    Branch    = 1'b0;

    ALUSrcA   = 2'b00;
    ALUSrcB   = 2'b00;
    ALUOp     = 2'b00;
    ResultSrc = 2'b00;
    AdrSrc    = 1'b0;
    MemWrite  = 1'b0;
    RegWrite  = 1'b0;
    IRWrite   = 1'b0;

    hart_halted = (state == S_HALTED);

    case (state)  

        S_FETCH : begin 

            ALUSrcA = 2'b00;    // from PC 
            ALUSrcB = 2'b10;    // 4 
            ALUOp = 2'b00;      // add 
            ResultSrc = 2'b10;  // alu result 
            PCUpdate = 1'b1;    // force pc write high 
            IRWrite = 1'b1;

            next_state = S_DECODE;
        end 

        S_DECODE : begin 
            case (op)                  
                OPCODE_I_TYPE_LOAD : begin 
                    next_state = S_MEMADR;
                end 
                OPCODE_S_TYPE : begin  
                    next_state = S_MEMADR;
                end 
                OPCODE_R_TYPE : begin 
                    next_state = S_EXECUTER;
                end 
                OPCODE_B_TYPE : begin 
                    ALUSrcA = 2'b01;
                    ALUSrcB = 2'b01;
                    ALUOp = 2'b00;
                    next_state = S_BEQ;
                end 
                OPCODE_I_TYPE_ALU : begin 
                    next_state = S_EXECUTEI; 
                end 

                OPCODE_J_TYPE : begin 
                    ALUSrcA = 2'b01;
                    ALUSrcB = 2'b01;
                    ALUOp = 2'b00;
                    next_state = S_JAL;
                end 
                default begin
                    next_state = S_FETCH;
                end
            endcase
        end 

        S_MEMADR : begin 
            ALUSrcA = 2'b10 ;
            ALUSrcB = 2'b01 ; 
            ALUOp   = 2'b00 ;
            if (op == OPCODE_I_TYPE_LOAD) begin
                next_state = S_MEMREAD;
            end else begin  // sw 
                next_state = S_MEMWRITE;
            end 
        end 

        S_MEMREAD : begin 
            ResultSrc = 2'b00;
            AdrSrc = 1'b1; 
            next_state = S_MEMWB;
            
        end 

        S_MEMWB : begin 
            ResultSrc  = 2'b01; 
            RegWrite   = 1'b1;
            next_state = S_FETCH; 
        end 

        S_MEMWRITE : begin 
            ResultSrc  = 2'b00; 
            AdrSrc     = 1'b1; 
            MemWrite   = 1'b1;
            next_state = S_FETCH;
        end 

        S_EXECUTER : begin 
            ALUSrcA    = 2'b10;
            ALUSrcB    = 2'b00;
            ALUOp      = 2'b10;
            next_state = S_ALUWB;
        end 

        S_EXECUTEI : begin 
            ALUSrcA    = 2'b10;
            ALUSrcB    = 2'b01;
            ALUOp      = 2'b10;
            next_state = S_ALUWB;
        end 

        S_ALUWB : begin 
            ResultSrc  =  2'b00; 
            RegWrite   = 1'b1;
            next_state = S_FETCH;
        end 

        S_JAL : begin 
            ALUSrcA    = 2'b01;
            ALUSrcB    = 2'b10;
            ALUOp      = 2'b00;
            ResultSrc  = 2'b00;
            PCUpdate   = 1'b1;
            next_state = S_ALUWB;
        end 

        S_BEQ : begin
            ALUSrcA    = 2'b10; 
            ALUSrcB    = 2'b00;
            ALUOp      = 2'b01; 
            ResultSrc  = 2'b00; 
            Branch     = 1'b1;
            next_state = S_FETCH; 
        end 

        S_HALTED : begin 
            PCUpdate    = 1'b0;
            RegWrite    = 1'b0;
            MemWrite    = 1'b0;
            IRWrite     = 1'b0;
            hart_halted = 1'b1; // how can i step then ? in this case 
        end 
        default begin 
            next_state = S_FETCH;
        end 
    endcase
    
end 
endmodule 
