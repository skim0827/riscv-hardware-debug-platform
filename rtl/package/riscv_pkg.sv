`timescale 1ns/1ps
package riscv_pkg;
    // page 407 
    typedef enum logic [4:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_AND,
        ALU_OR,
        ALU_XOR,
        ALU_SLT,
        ALU_SLTU,
        ALU_SLL,
        ALU_SRL,
        ALU_SRA,
        // RVM (Table B.5): funct7=0000001, opcode=0110011
        ALU_MUL,     // funct3=000  rd = (rs1*rs2)[31:0]  signed×signed
        ALU_MULH,    // funct3=001  rd = (rs1*rs2)[63:32] signed×signed
        ALU_MULHSU,  // funct3=010  rd = (rs1*rs2)[63:32] signed×unsigned
        ALU_MULHU,   // funct3=011  rd = (rs1*rs2)[63:32] unsigned×unsigned
        ALU_DIV,     // funct3=100  rd = rs1/rs2  (signed)
        ALU_DIVU,    // funct3=101  rd = rs1/rs2  (unsigned)
        ALU_REM,     // funct3=110  rd = rs1%rs2  (signed)
        ALU_REMU     // funct3=111  rd = rs1%rs2  (unsigned)
    }alu_control_t;

    typedef enum logic [3:0] {
        S_FETCH,
        S_DECODE, 
        S_MEMADR,
        S_MEMREAD,
        S_MEMWB,
        S_MEMWRITE,
        S_EXECUTER,
        S_ALUWB, 
        S_EXECUTEI, 
        S_JAL,
        S_JALR_WB,
        S_BRANCH,
        S_HALTED,
        S_LUI,
        S_JALR, 
        S_AUIPC
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
