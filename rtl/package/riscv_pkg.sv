`timescale 1ns/1ps
package riscv_pkg;
    // page 407 
    typedef enum logic [3:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_AND,
        ALU_OR,
        ALU_XOR,
        ALU_SLT,
        ALU_SLTU,
        ALU_SLL,
        ALU_SRL,
        ALU_SRA
    }alu_control_t;

    typedef enum logic [3:0] {
        S_FETCH = 4'b0000,
        S_DECODE = 4'b0001, 
        S_MEMADR = 4'b0010,
        S_MEMREAD = 4'b0011,
        S_MEMWB = 4'b0100,
        S_MEMWRITE = 4'b0101,
        S_EXECUTER = 4'b0110,
        S_ALUWB = 4'b0111, 
        S_EXECUTEI = 4'b1000, 
        S_JAL = 4'b1001,
        S_BRANCH = 4'b1010,
        S_HALTED = 4'b1011
    } state_t;


    typedef enum logic [6:0] {
        OPCODE_R_TYPE         = 7'b0110011,
        OPCODE_I_TYPE_ALU     = 7'b0010011,
        OPCODE_I_TYPE_LOAD    = 7'b0000011,
        OPCODE_S_TYPE         = 7'b0100011,
        OPCODE_B_TYPE         = 7'b1100011,
        OPCODE_U_TYPE_LUI     = 7'b0110111,
        OPCODE_U_TYPE_AUIPC   = 7'b0010111,
        OPCODE_J_TYPE         = 7'b1101111,
        OPCODE_I_TYPE_JALR    = 7'b1100111
    } opcode_t;

    typedef enum logic [7:0] {
        CMD_HALT = 8'h00,
        CMD_RESUME = 8'h01,
        CMD_STEP = 8'h02,

        CMD_READ_REG = 8'h10, 
        CMD_WRITE_REG = 8'h11, 

        CMD_READ_PC = 8'h20,
        CMD_WRITE_PC = 8'h21 
    } debug_cmd_t;


    typedef enum logic [3:0] {
        EXIT2_DR = 4'd0,
        EXIT1_DR ,
        SHIFT_DR , 
        PAUSE_DR ,
        SELECT_IR_SCAN, 
        UPDATE_DR,
        CAPTURE_DR,
        SELECT_DR_SCAN,
        EXIT2_IR,
        EXIT1_IR,
        SHIFT_IR,
        PAUSE_IR,
        RUN_TEST_IDLE,
        UPDATE_IR,
        CAPTURE_IR,
        TEST_LOGIC_RESET
    } tap_t;


    typedef enum logic [3:0] { 
        IR_IDCODE = 4'b0001,
        IR_BYPASS = 4'b1111,
        IR_DEBUG = 4'b0010
    } ir_t;
endpackage
