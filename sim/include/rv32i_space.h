#ifndef RV32I_SPACE_H
#define RV32I_SPACE_H
#include "rv32i.h"


// EDAC overhead 
#define CYCLES_EDAC_ENCODE 1 // store : compute check bits before write 
#define CYCLES_EDAC_DECODE 2 // load : syndrome check before data is valid 


// TMR overhead
#define CYCLES_TMR_VOTE 1 

typedef enum {
    SPACE_MODE_BOTH,
    SPACE_MODE_EDAC_ONLY,
    SPACE_MODE_TMR_ONLY
} space_reliability_t;


typedef struct {
    uint32_t regs[3][32]; // TMR  
    uint32_t pc; 
    uint64_t mem_protected[MEM_WORDS];  // bits [31:0] = data, bits [38:32] = ECC

    uint64_t instrs; // how many instructions have been executed so far
    uint64_t cycles; 
    
    uint32_t edac_corrections; // single bit errors corrected 
    uint32_t edac_detections; // double bit errors detected (uncorrectable)
    uint32_t tmr_corrections; // reg reads where voter had to correct a mismatch 
    
    bool halted; 
    sim_mode_t mode; 
    space_reliability_t reliability;
    // TO DO : edac_corrections / total_reads
} cpu_space_t; 

uint8_t edac_encode(uint32_t data);
uint32_t edac_decode(uint32_t data, uint8_t stored_ecc, bool *corrected, bool *detected);

uint32_t mem_read_w_space (cpu_space_t *cpu, uint32_t addr);
uint16_t mem_read_h_space (cpu_space_t *cpu, uint32_t addr);
uint8_t  mem_read_b_space (cpu_space_t *cpu, uint32_t addr);
void     mem_write_w_space(cpu_space_t *cpu, uint32_t addr, uint32_t val);
void     mem_write_h_space(cpu_space_t *cpu, uint32_t addr, uint16_t val);
void     mem_write_b_space(cpu_space_t *cpu, uint32_t addr, uint8_t  val);

void cpu_space_reset(cpu_space_t *cpu);
void load_hex_space(cpu_space_t *cpu, const char *filename);


uint32_t tmr_vote (uint32_t a, uint32_t b, uint32_t c, bool *corrected);

void step_space(cpu_space_t *cpu , bool trace);


void fault_inject_mem_bit(cpu_space_t *cpu);
void fault_inject_reg_bit(cpu_space_t *cpu);
void fault_inject_print_stats(cpu_space_t *cpu);

#endif 