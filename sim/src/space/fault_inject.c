#include "rv32i_space.h"
#include <stdlib.h>
#include <stdio.h>

void fault_inject_mem_bit(cpu_space_t *cpu){
    uint32_t random_word_index = (uint32_t)(rand() % MEM_WORDS);
    uint32_t random_bit_pos = (uint32_t)(rand()%32);
    cpu -> mem_protected[random_word_index] ^= (uint64_t)(1u << random_bit_pos);
};

void fault_inject_reg_bit(cpu_space_t *cpu){
    uint32_t random_copy = (uint32_t)(rand() % 3);
    uint32_t random_reg_number = (uint32_t)(rand()%32);
    int random_bit_pos = (uint32_t)(rand()%32);
    cpu -> regs[random_copy][random_reg_number] ^= (uint32_t)(1u << random_bit_pos);
    fprintf(stderr, "[FAULT] regs[%u][%u] bit %u flipped\n",
            random_copy, random_reg_number, random_bit_pos);

};

void fault_inject_print_stats(cpu_space_t *cpu){
    printf("\n--- Space Reliability Stats ---\n");
    printf("EDAC corrections (1-bit, corrected) : %u\n", cpu -> edac_corrections);
    printf("EDAC detections (2-bit, uncorrected): %u\n", cpu->edac_detections);
    printf("TMR corrections (voter mismatch) : %u\n", cpu->tmr_corrections);

    if (cpu -> instrs > 0) { 
        // corrections per 1000 instructions
        printf("EDAC corrections per 1000 instrs : %.4f\n", (double) cpu -> edac_corrections / (double) cpu -> instrs * 1000.0);
        printf("TMR corrections per 1000 instrs : %.4f\n", (double) cpu -> tmr_corrections / (double) cpu->instrs * 1000.0);

    }
};