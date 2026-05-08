#include "rv32i_space.h"

uint8_t edac_encode(uint32_t data){}

uint32_t edac_decode(uint32_t data, uint8_t stored_ecc, bool *corrected, bool *detected);

void     mem_write_w_space(cpu_space_t *cpu, uint32_t addr, uint32_t val);
uint32_t mem_read_w_space (cpu_space_t *cpu, uint32_t addr);

void cpu_space_reset(cpu_space_t *cpu);
void load_hex_space(cpu_space_t *cpu, const char *filename);