#ifndef RV32I
#define RV32I

#include <stdint.h>
#include <stdbool.h>

#define MEM_WORDS 16384 

#define CYCLES_FETCH 1
#define CYCLES_DECODE 1 
#define CYCLES_EXECUTE 1 
#define CYCLES_MEM 1 
#define CYCLES_WD 1 

#define CYCLES_ALU 4 
#define CYCLES_LOAD 5 
#define CYCLES_STORE 4 
#define CYCLES_BRANCH   3
#define CYCLES_JAL      4
#define CYCLES_JALR     4
#define CYCLES_LUI      4
#define CYCLES_AUIPC    4


typedef enum {
    MODE_MULTICYCLE // Will add others later
} sim_mode_t ;

typedef struct {
    uint32_t regs[32]; 
    uint32_t pc; 
    uint32_t mem[MEM_WORDS]; 

    uint64_t instrs; 
    uint64_t cycles; 

    bool halted; 
    sim_mode_t mode; 
} cpu_t; 

#define OPCODE(i)   ((i) & 0x7F)
#define RD(i)       (((i) >>  7) & 0x1F)
#define FUNCT3(i)   (((i) >> 12) & 0x07)
#define RS1(i)      (((i) >> 15) & 0x1F)
#define RS2(i)      (((i) >> 20) & 0x1F)
#define FUNCT7(i)   (((i) >> 25) & 0x7F)


#define OP_R        0x33   // ADD SUB AND OR XOR SLL SRL SRA SLT SLTU
#define OP_I_ALU    0x13   // ADDI SLTI ANDI ORI XORI SLLI SRLI SRAI
#define OP_LOAD     0x03   // LW LH LB LHU LBU
#define OP_STORE    0x23   // SW SH SB
#define OP_BRANCH   0x63   // BEQ BNE BLT BGE BLTU BGEU
#define OP_LUI      0x37   // LUI
#define OP_AUIPC    0x17   // AUIPC
#define OP_JAL      0x6F   // JAL
#define OP_JALR     0x67   // JALR
#define OP_SYSTEM   0x73   // ECALL EBREAK

// memory.c
void cpu_reset(cpu_t *cpu);
void load_hex(cpu_t *cpu, const char *filename);
uint32_t mem_read_w (cpu_t *cpu, uint32_t addr);
uint16_t mem_read_h(cpu_t *cpu, uint32_t addr);
uint8_t mem_read_b(cpu_t *cpu, uint32_t addr);
void mem_write_w(cpu_t *cpu, uint32_t addr, uint32_t val);
void mem_write_h(cpu_t *cpu, uint32_t addr, uint16_t val);
void mem_write_b(cpu_t *cpu, uint32_t addr, uint8_t val);

// execute.c 
void step(cpu_t *cpu, bool trace );

// trace.c 
void trace_print(cpu_t *cpu, uint32_t pc, uint32_t inst);

#endif 