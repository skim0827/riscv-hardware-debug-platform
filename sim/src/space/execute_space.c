#include "rv32i_space.h"
#include <stdio.h>
#include <stdlib.h>

uint32_t tmr_vote (uint32_t a, uint32_t b, uint32_t c, bool *corrected){
    uint32_t result = (a&b) | (a&c) | (b&c);
    *corrected = !((a==b)&&(b==c));
    return result; 
};


static int32_t imm_i(uint32_t instr) { // extract immediate value 
    return (int32_t) instr >> 20;
}

static int32_t imm_s(uint32_t instr) {
    return ((int32_t)(instr & 0xFE000000) >> 20)
         | ((instr >> 7) & 0x1F);
}

static int32_t imm_b(uint32_t instr) {
    return ((int32_t)(instr & 0x80000000) >> 19)
         | ((instr & 0x00000080) <<  4)
         | ((instr & 0x7E000000) >> 20)
         | ((instr & 0x00000F00) >> 7);
}

static int32_t imm_u(uint32_t instr) {
    return (int32_t)(instr & 0xFFFFF000);
}

static int32_t imm_j(uint32_t instr) {
    return ((int32_t)(instr & 0x80000000) >> 11)
         | (instr & 0x000FF000)
         | ((instr & 0x00100000) >>  9)
         | ((instr & 0x7FE00000) >> 20);
}


static void add_cycles(cpu_space_t *cpu, uint32_t op, uint32_t f3) { 
    switch (op)
    {
    case OP_R : cpu -> cycles += CYCLES_ALU; break;
    case OP_I_ALU:  cpu->cycles += CYCLES_ALU;    break;
    case OP_LOAD:   cpu->cycles += CYCLES_LOAD;   break;
    case OP_STORE:  cpu->cycles += CYCLES_STORE;  break;
    case OP_BRANCH: cpu->cycles += CYCLES_BRANCH; break;
    case OP_JAL:    cpu->cycles += CYCLES_JAL;    break;
    case OP_JALR:   cpu->cycles += CYCLES_JALR;   break;
    case OP_LUI:    cpu->cycles += CYCLES_LUI;    break;
    case OP_AUIPC:  cpu->cycles += CYCLES_AUIPC;  break;
    default:        cpu->cycles += 1;             break;
    }
    cpu ->cycles += CYCLES_TMR_VOTE;
    (void) f3; 
}


void step_space(cpu_space_t *cpu , bool trace){
    uint32_t pc = cpu -> pc; // byte address 
    uint32_t instr = mem_read_w_space(cpu, pc);

    uint32_t op = OPCODE(instr);
    uint32_t rd  = RD(instr);
    uint32_t rs1 = RS1(instr);
    uint32_t rs2 = RS2(instr);
    uint32_t f3  = FUNCT3(instr);
    uint32_t f7  = FUNCT7(instr);

    if (trace) trace_print((cpu_t *)cpu, pc, instr);
    bool tmr_corr = false; 

    uint32_t a = tmr_vote(cpu->regs[0][rs1], 
                          cpu->regs[1][rs1], 
                          cpu->regs[2][rs1], &tmr_corr);
    
    if (tmr_corr) cpu -> tmr_corrections++;

    tmr_corr = false; 
    uint32_t b = tmr_vote(cpu->regs[0][rs2], 
                          cpu->regs[1][rs2], 
                          cpu->regs[2][rs2], &tmr_corr);

    if (tmr_corr) cpu -> tmr_corrections++;

    cpu -> pc = pc +4;


    // =======================execute=========================

    // EXECUTE 
    switch (op)
    {
        // R-TYPE: ADD SUB AND OR XOR SLL SRL SRA SLT SLTU
        case OP_R : {
            uint32_t result = 0;

            switch (f3)
            {
                case 0x0 : result = (f7 & 0x20) ? a - b : a + b; break; 
                case 0x1 : result = a << (b & 0x1F); break; 
                case 0x2: result = ((int32_t)a < (int32_t)b) ? 1 : 0; break;
                case 0x3 : result = (a < b) ? 1 : 0; break; 
                case 0x4: result = a ^ b; break ;
                case 0x5 : result = (f7 & 0x20)
                                    ? (uint32_t)((int32_t)a >> (b & 0x1F))
                                    : a >> (b & 0x1F); break ;
                case 0x6: result = a | b; break;
                case 0x7: result = a & b; break;
                default : 
                    fprintf(stderr, "Unknown funct3: %u\n", f3);
                    exit(1);break;
            }
        if (rd) {cpu->regs[0][rd] = cpu->regs[1][rd] = cpu->regs[2][rd] = result;} break ; 
        }

        case OP_I_ALU : {
            int32_t imm = imm_i(instr);
            uint32_t result = 0;
            uint32_t shamt = (instr >> 20) & 0x1F;
            switch (f3)
            {
                case 0x0 : result = a + (uint32_t)imm; break; 
                case 0x1 : result = a << shamt; break; 
                case 0x2 : result = ((int32_t)a < imm) ? 1 : 0; break;  
                case 0x3: result = (a < (uint32_t)imm) ? 1 : 0;break; 
                case 0x4: result = a ^ (uint32_t)imm;break; 
                case 0x5: result = (f7 & 0x20)
                                 ? (uint32_t)((int32_t)a >> shamt)               // SRAI
                                 : a >> shamt; break; 
                case 0x6: result = a | (uint32_t)imm; break;  
                case 0x7: result = a & (uint32_t)imm;break; 
                default : 
                    fprintf(stderr, "Unknown funct3: %u\n", f3);
                    exit(1);break;
            }
            if (rd) {cpu->regs[0][rd] = cpu->regs[1][rd] = cpu->regs[2][rd] = result;}
            break ;
        }

        case OP_LOAD: {
            uint32_t addr = (uint32_t)((uint32_t) a + imm_i(instr));
            uint32_t result = 0;
            switch (f3)
            {
            case 0x0: result =  (uint32_t)(int32_t)(int8_t)mem_read_b_space(cpu, addr); break; 
            case 0x1: result =  (uint32_t)(int32_t)(int16_t)mem_read_h_space(cpu, addr); break;      
            case 0x2: result =  mem_read_w_space(cpu, addr); break;
            case 0x4: result = (uint32_t)mem_read_b_space(cpu, addr); break;
            case 0x5: result = (uint32_t)mem_read_h_space(cpu, addr); break; 
            default : fprintf(stderr, "Unknown LOAD funct3=0x%X at PC=0x%08X\n", f3, pc); exit(1);break;
            }
            if(rd) cpu->regs[0][rd] = cpu->regs[1][rd] = cpu->regs[2][rd] = result;
            break; 
        }

        case OP_STORE: {
            uint32_t addr = (uint32_t)((int32_t)a + imm_s(instr));
            switch (f3)
            {
                case 0x0: mem_write_b_space(cpu, addr, (uint8_t) b); break; // SB
                case 0x1: mem_write_h_space(cpu, addr, (uint16_t)b); break; // SH
                case 0x2: mem_write_w_space(cpu, addr,           b); break; // SW
                default:
                    fprintf(stderr, "Unknown STORE funct3=0x%X at PC=0x%08X\n", f3, pc);
                    exit(1);break;
            }
            break; 

        }

        case OP_BRANCH: {
            bool taken = 0;

            switch (f3)
            {
                case 0x0: taken = (a == b);                              break; // BEQ
                case 0x1: taken = (a != b);                              break; // BNE
                case 0x4: taken = ((int32_t)a <  (int32_t)b);           break; // BLT
                case 0x5: taken = ((int32_t)a >= (int32_t)b);           break; // BGE
                case 0x6: taken = (a <  b);                              break; // BLTU
                case 0x7: taken = (a >= b);                              break; // BGEU
                default:
                    fprintf(stderr, "Unknown BRANCH funct3=0x%X at PC=0x%08X\n", f3, pc);
                    exit(1);break;
            }
            if (taken) {cpu ->pc = (uint32_t)((int32_t)pc + imm_b(instr));} break;
        }

        case OP_LUI: {
            if (rd) {cpu->regs[0][rd] = cpu->regs[1][rd] = cpu->regs[2][rd] =(uint32_t)imm_u(instr);} break;
        }

        case OP_AUIPC: {
            if (rd) cpu->regs[0][rd] = cpu->regs[1][rd] = cpu->regs[2][rd] =(uint32_t)((int32_t)pc + imm_u(instr));
            break;
        }

        case OP_JAL: {
            uint32_t ret = pc + 4;
            cpu->pc = (uint32_t)((int32_t)pc + imm_j(instr));
            if (rd) cpu->regs[0][rd] = cpu->regs[1][rd] = cpu->regs[2][rd]  = ret; // return address stored 
            break; 
        }


        case OP_JALR: {
            uint32_t ret = pc + 4;
            cpu->pc = (uint32_t)((int32_t)a + imm_i(instr)) & ~1u;
            if (rd) cpu->regs[0][rd] = cpu->regs[1][rd] = cpu->regs[2][rd]  = ret;
            break;
        }

        // SYSTEM: EBREAK / ECALL — halt simulation
        case OP_SYSTEM: {
            if (instr == 0x00100073) { // EBREAK
                printf("\n[ISS] EBREAK at PC=0x%08X — halting\n", pc);
            } else {
                printf("\n[ISS] ECALL at PC=0x%08X — halting\n", pc);
            }
            cpu->halted = true;
            break;
        }


        default: 
            fprintf(stderr, "[ISS] Unknown opcode 0x%02X at PC=0x%08X instr=0x%08X\n", 
                    op, pc, instr);
            cpu ->halted = true;
            break; 

    }
    cpu ->regs[0][0] = cpu ->regs[1][0] = cpu ->regs[2][0] = 0; // always 0 
    cpu ->instrs++;
    add_cycles(cpu, op, f3);

};

