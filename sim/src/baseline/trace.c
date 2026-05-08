#include <stdio.h>
#include <string.h>
#include "rv32i.h"


static const char *abi_name[32] = {
    "zero", "ra", "sp", "gp", "tp",
    "t0",   "t1", "t2",
    "s0",   "s1",
    "a0",   "a1", "a2", "a3", "a4", "a5", "a6", "a7",
    "s2",   "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11",
    "t3",   "t4", "t5", "t6"
};

static void decode_mnemonic(uint32_t instr, uint32_t pc, char *buf, size_t bufsz) {
    uint32_t op  = OPCODE(instr);
    uint32_t rd  = RD(instr);
    uint32_t rs1 = RS1(instr);
    uint32_t rs2 = RS2(instr);
    uint32_t f3  = FUNCT3(instr);
    uint32_t f7  = FUNCT7(instr);

    // Immediate extraction (inline here — trace.c is standalone)
    int32_t  imm_i = (int32_t)instr >> 20;
    int32_t  imm_s = ((int32_t)(instr & 0xFE000000) >> 20) | ((instr >> 7) & 0x1F);
    int32_t  imm_b = ((int32_t)(instr & 0x80000000) >> 19)
                   | ((instr & 0x00000080) << 4)
                   | ((instr & 0x7E000000) >> 20)
                   | ((instr & 0x00000F00) >> 7);
    int32_t  imm_u = (int32_t)(instr & 0xFFFFF000);
    int32_t  imm_j = ((int32_t)(instr & 0x80000000) >> 11)
                   | (instr & 0x000FF000)
                   | ((instr & 0x00100000) >> 9)
                   | ((instr & 0x7FE00000) >> 20);
    uint32_t shamt = (instr >> 20) & 0x1F;

    switch (op) {
        case OP_R:
            switch (f3) {
                case 0x0: snprintf(buf, bufsz, "%s %s,%s,%s",
                              (f7 & 0x20) ? "sub" : "add",
                              abi_name[rd], abi_name[rs1], abi_name[rs2]); break;
                case 0x1: snprintf(buf, bufsz, "sll %s,%s,%s",
                              abi_name[rd], abi_name[rs1], abi_name[rs2]); break;
                case 0x2: snprintf(buf, bufsz, "slt %s,%s,%s",
                              abi_name[rd], abi_name[rs1], abi_name[rs2]); break;
                case 0x3: snprintf(buf, bufsz, "sltu %s,%s,%s",
                              abi_name[rd], abi_name[rs1], abi_name[rs2]); break;
                case 0x4: snprintf(buf, bufsz, "xor %s,%s,%s",
                              abi_name[rd], abi_name[rs1], abi_name[rs2]); break;
                case 0x5: snprintf(buf, bufsz, "%s %s,%s,%s",
                              (f7 & 0x20) ? "sra" : "srl",
                              abi_name[rd], abi_name[rs1], abi_name[rs2]); break;
                case 0x6: snprintf(buf, bufsz, "or %s,%s,%s",
                              abi_name[rd], abi_name[rs1], abi_name[rs2]); break;
                case 0x7: snprintf(buf, bufsz, "and %s,%s,%s",
                              abi_name[rd], abi_name[rs1], abi_name[rs2]); break;
                default:  snprintf(buf, bufsz, "unknown_r"); break;
            }
            break;

        case OP_I_ALU:
            switch (f3) {
                case 0x0: snprintf(buf, bufsz, "addi %s,%s,%d",
                              abi_name[rd], abi_name[rs1], imm_i); break;
                case 0x1: snprintf(buf, bufsz, "slli %s,%s,%u",
                              abi_name[rd], abi_name[rs1], shamt); break;
                case 0x2: snprintf(buf, bufsz, "slti %s,%s,%d",
                              abi_name[rd], abi_name[rs1], imm_i); break;
                case 0x3: snprintf(buf, bufsz, "sltiu %s,%s,%d",
                              abi_name[rd], abi_name[rs1], imm_i); break;
                case 0x4: snprintf(buf, bufsz, "xori %s,%s,%d",
                              abi_name[rd], abi_name[rs1], imm_i); break;
                case 0x5: snprintf(buf, bufsz, "%s %s,%s,%u",
                              (f7 & 0x20) ? "srai" : "srli",
                              abi_name[rd], abi_name[rs1], shamt); break;
                case 0x6: snprintf(buf, bufsz, "ori %s,%s,%d",
                              abi_name[rd], abi_name[rs1], imm_i); break;
                case 0x7: snprintf(buf, bufsz, "andi %s,%s,%d",
                              abi_name[rd], abi_name[rs1], imm_i); break;
                default:  snprintf(buf, bufsz, "unknown_i"); break;
            }
            break;

        case OP_LOAD:
            switch (f3) {
                case 0x0: snprintf(buf, bufsz, "lb %s,%d(%s)",
                              abi_name[rd], imm_i, abi_name[rs1]); break;
                case 0x1: snprintf(buf, bufsz, "lh %s,%d(%s)",
                              abi_name[rd], imm_i, abi_name[rs1]); break;
                case 0x2: snprintf(buf, bufsz, "lw %s,%d(%s)",
                              abi_name[rd], imm_i, abi_name[rs1]); break;
                case 0x4: snprintf(buf, bufsz, "lbu %s,%d(%s)",
                              abi_name[rd], imm_i, abi_name[rs1]); break;
                case 0x5: snprintf(buf, bufsz, "lhu %s,%d(%s)",
                              abi_name[rd], imm_i, abi_name[rs1]); break;
                default:  snprintf(buf, bufsz, "unknown_load"); break;
            }
            break;

        case OP_STORE:
            switch (f3) {
                case 0x0: snprintf(buf, bufsz, "sb %s,%d(%s)",
                              abi_name[rs2], imm_s, abi_name[rs1]); break;
                case 0x1: snprintf(buf, bufsz, "sh %s,%d(%s)",
                              abi_name[rs2], imm_s, abi_name[rs1]); break;
                case 0x2: snprintf(buf, bufsz, "sw %s,%d(%s)",
                              abi_name[rs2], imm_s, abi_name[rs1]); break;
                default:  snprintf(buf, bufsz, "unknown_store"); break;
            }
            break;

        case OP_BRANCH:
            switch (f3) {
                case 0x0: snprintf(buf, bufsz, "beq %s,%s,0x%08X",
                              abi_name[rs1], abi_name[rs2], (uint32_t)(pc + imm_b)); break;
                case 0x1: snprintf(buf, bufsz, "bne %s,%s,0x%08X",
                              abi_name[rs1], abi_name[rs2], (uint32_t)(pc + imm_b)); break;
                case 0x4: snprintf(buf, bufsz, "blt %s,%s,0x%08X",
                              abi_name[rs1], abi_name[rs2], (uint32_t)(pc + imm_b)); break;
                case 0x5: snprintf(buf, bufsz, "bge %s,%s,0x%08X",
                              abi_name[rs1], abi_name[rs2], (uint32_t)(pc + imm_b)); break;
                case 0x6: snprintf(buf, bufsz, "bltu %s,%s,0x%08X",
                              abi_name[rs1], abi_name[rs2], (uint32_t)(pc + imm_b)); break;
                case 0x7: snprintf(buf, bufsz, "bgeu %s,%s,0x%08X",
                              abi_name[rs1], abi_name[rs2], (uint32_t)(pc + imm_b)); break;
                default:  snprintf(buf, bufsz, "unknown_branch"); break;
            }
            break;

        case OP_LUI:
            snprintf(buf, bufsz, "lui %s,0x%05X",
                     abi_name[rd], (uint32_t)imm_u >> 12);
            break;

        case OP_AUIPC:
            snprintf(buf, bufsz, "auipc %s,0x%05X",
                     abi_name[rd], (uint32_t)imm_u >> 12);
            break;

        case OP_JAL:
            snprintf(buf, bufsz, "jal %s,0x%08X",
                     abi_name[rd], (uint32_t)(pc + imm_j));
            break;

        case OP_JALR:
            snprintf(buf, bufsz, "jalr %s,%d(%s)",
                     abi_name[rd], imm_i, abi_name[rs1]);
            break;

        case OP_SYSTEM:
            snprintf(buf, bufsz, "%s", (instr == 0x00100073) ? "ebreak" : "ecall");
            break;

        default:
            snprintf(buf, bufsz, "unknown_0x%02X", op);
            break;
    }
    (void)f7; // suppress unused warning for some paths
}

void trace_print(cpu_t *cpu, uint32_t pc, uint32_t instr) {
    char mnemonic[64];
    decode_mnemonic(instr, pc, mnemonic, sizeof(mnemonic));
    printf("PC=%08X | %08X | %-32s\n", pc, instr, mnemonic);
    (void)cpu; 
}