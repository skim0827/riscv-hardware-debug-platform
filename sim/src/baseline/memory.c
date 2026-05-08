#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "rv32i.h"

void cpu_reset(cpu_t *cpu) {

    memset(cpu -> regs, 0, sizeof(cpu->regs));
    cpu -> pc = 0; 
    cpu -> instrs = 0; 
    cpu -> cycles = 0; 
    cpu -> halted = false; 
    // memory keeps loaded program 
}

// here !!!!!!!!!!!!!!!!!!!
void load_hex(cpu_t *cpu, const char *filename) {
    FILE *f = fopen(filename, "r");
    if (!f) {
        perror("load_hex : cannot open file");
        exit(1);
    } 
    memset(cpu -> mem, 0, sizeof(cpu->mem)); // reset memory 

    uint32_t addr = 0; 
    char line[128];

    while (fgets(line, sizeof(line), f)) { // read a line into line 
        if (line[0] == '\n' || line[0] == '\r') continue; // first char of line 
        if (line[0] == '@') {
            addr = (uint32_t)strtoul(&line[1], NULL, 16);
        } else {
            uint32_t word = (uint32_t)strtoul(line, NULL,16); 
            if (addr < MEM_WORDS) { 
                cpu -> mem[addr] = word; 
                addr++;
            } else {
                fprintf(stderr, "load_hex : address 0x%08X exceeds MEM_WORDS\n", addr);
            }
        }
    }
    fclose(f);

}

static void check_addr(uint32_t addr, uint32_t size, const char *op) {
    uint32_t byte_limit  = MEM_WORDS * 4;
    if (addr + size > byte_limit){
        fprintf(stderr, "MEMORY FAULT: %s at 0x%08X out of range (limit 0x%08X)\n",
                op, addr, byte_limit);
        exit(1);
    }
}

uint32_t mem_read_w(cpu_t *cpu, uint32_t addr) {
    check_addr(addr, 4, "READ_W"); 
    if (addr & 0x3) { 
        fprintf(stderr, "ALIGNMENT FAULT: LW at 0x%08X not word-aligned\n", addr);
        exit(1);
    }
    return cpu -> mem[addr/4];
}

uint16_t mem_read_h(cpu_t *cpu, uint32_t addr) {
    check_addr(addr, 2, "READ_H"); 
    if (addr & 0x01) {
        fprintf(stderr, "ALIGNMENT FAULT: LH at 0x%08X not halfword-aligned\n", addr);
        exit(1);
    }
    uint32_t word = cpu -> mem[addr/4];
    uint32_t shift = (addr & 0x2) * 8; // shift 0 or 16
    return (uint16_t) (word >> shift);
}

uint8_t mem_read_b(cpu_t *cpu, uint32_t addr) { 
    check_addr(addr, 1, "READ_B");
    uint32_t word = cpu -> mem[addr/4];
    uint32_t shift = (addr & 0x3); // 0, 8, 16, 24 bits 
    return (uint8_t) (word >> shift );
}

void mem_write_w(cpu_t *cpu, uint32_t addr, uint32_t val){
    check_addr(addr, 4, "WRITE_H");
    if (addr & 0x3) {
        fprintf(stderr, "ALIGNMENT FAULT: SW at 0x%08X not word-aligned\n", addr);
        exit(1);
    }
    cpu -> mem [addr/4] = val;
}

void mem_write_h(cpu_t *cpu, uint32_t addr, uint16_t val) {
    check_addr(addr, 2, "WRITE_H");
    if (addr & 0x1) {
        fprintf(stderr, "ALIGNMENT FAULT: SH at 0x%08X not halfword-aligned\n", addr);
        exit(1);
    }
    uint32_t shift  = (addr & 0x2) * 8;
    uint32_t mask   = 0xFFFF << shift;
    cpu->mem[addr / 4] = (cpu->mem[addr / 4] & ~mask) | ((uint32_t)val << shift);
}

void mem_write_b(cpu_t *cpu, uint32_t addr, uint8_t val) {
    check_addr(addr, 1, "WRITE_B");
    uint32_t shift  = (addr & 0x3) * 8;
    uint32_t mask   = 0xFF << shift;
    cpu->mem[addr / 4] = (cpu->mem[addr / 4] & ~mask) | ((uint32_t)val << shift);
}