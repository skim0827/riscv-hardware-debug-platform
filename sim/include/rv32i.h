#ifndef RV32I
#define RV32I

#include <stdint.h>

#define MEM_SIZE_WORDS 4096 

typedef struct {
    uint32_t regs[32]; 
    uint32_t pc; 
    uint32_t mem[MEM_SIZE_WORDS]; 
    uint64_t cycles; 
    uint64_t instrs; 
} cpu_t; 

static inline void cpu_reset(cpu_t *cpu){
    for (int i = 0; i  < 32; i++) cpu ->regs[i] = 0;
    cpu -> pc = 0; 
    cpu -> cycles = 0;
    cpu -> instrs = 0; 
}


#endif 