#include "rv32i_space.h"
#include <stdlib.h>
#include <stdio.h>
#include "string.h"
uint8_t edac_encode(uint32_t data){
    // returns 7 ECC bits 
    static const uint8_t cw_pos[32] = {
        3,  5,  6,  7,  9, 10, 11, 12, 13, 14, 15,
        17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
        28, 29, 30, 31, 33, 34, 35, 36, 37, 38
    };

    uint8_t h = 0; // 6 Hamming parity bits packed together
    for (int i = 0; i < 32; i++) {
        if((data >> i) & 1u) {
            h ^= cw_pos[i];
        }
    }
    h &= 0x3F; // 6 bits 
    uint8_t p0 = (uint8_t)__builtin_parity(data) ^ (uint8_t)__builtin_parity(h);
    return (p0 << 6) | h ; // bit[6]=p0, bits[5:0] = p5 - p1
}

uint32_t edac_decode(uint32_t data, uint8_t stored_ecc, bool *corrected, bool *detected){
    *corrected = false;
    *detected = false;
    static const uint8_t cw_pos[32] = {
         3,  5,  6,  7,  9, 10, 11, 12, 13, 14, 15,
        17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
        28, 29, 30, 31, 33, 34, 35, 36, 37, 38
    };

    uint8_t h = 0;  // the expected Hamming parity
    for (int i=0; i < 32; i++) {
        if ((data >> i) & 1u) h ^= cw_pos[i];
    }
    h &= 0x3F;

    uint8_t stored_hamming = stored_ecc & 0x3F;
    uint8_t stored_overall = (stored_ecc >> 6) & 1; // P0
    uint8_t syndrome = h ^ (stored_hamming) ; // new parity XOR old parity

    uint8_t overall_err =
        __builtin_parity(data) ^
        __builtin_parity(h) ^
        stored_overall;

    if (syndrome == 0 && overall_err == 0) {
        return data;
    }
    if (syndrome != 0 && overall_err != 0 ) { 
        *corrected = true; 
        for (int i=0; i < 32; i ++) {
            if (cw_pos[i] == syndrome) return data ^ (1u << i); // flip
        }
        return data;
    }
    if (syndrome != 0 && overall_err == 0){ 
        *detected = true; 
        return data;
    }

    return data; // syndrome == 0 && overall_err != 0
};

void     mem_write_w_space(cpu_space_t *cpu, uint32_t addr, uint32_t val){
    if (addr & 0x3) { 
        fprintf(stderr, "ALIGNMENT FAULT : SW at 0x%08x not word-aligned\n", addr);
        exit(1);
    }
    if ((addr/4) >= MEM_WORDS) { 
        fprintf(stderr, "MEMORY FAULT : WRITE_W at 0x%08x out of range\n", addr);
        exit(1);
    }

    uint8_t ecc = edac_encode(val);
    uint64_t word = (((uint64_t) ecc<< 32) | val);
    cpu -> mem_protected[addr/4] = word;
    cpu -> cycles += CYCLES_EDAC_ENCODE;
};

void     mem_write_h_space(cpu_space_t *cpu, uint32_t addr, uint16_t val){
    if (addr & 0x1) { 
        fprintf(stderr, "ALIGNMENT FAULT : SW at 0x%08x not word-aligned\n", addr);
        exit(1);
    }
    if ((addr/4) >= MEM_WORDS) { 
        fprintf(stderr, "MEMORY FAULT : WRITE_H at 0x%08x out of range\n", addr);
        exit(1);
    }

    // read existing full word
    uint64_t existing = cpu -> mem_protected[addr/4];
    uint32_t data = (uint32_t) (existing & 0xFFFFFFFF);
    uint8_t old_ecc = (uint8_t) (existing >> 32);
    bool corrected =false, detected = false;
    data = edac_decode(data, old_ecc, &corrected, &detected);
    if(corrected) cpu -> edac_corrections++;
    if(detected) cpu -> edac_detections++;

    uint32_t shift  = (addr & 0x2) * 8;
    uint32_t mask = 0xFFFF << shift; 
    data = (data & mask) | ((uint32_t) val << shift);

    uint8_t ecc = edac_encode(data);
    cpu -> mem_protected[addr/4] = ((uint64_t) ecc << 32) | data;
    cpu -> cycles += CYCLES_EDAC_ENCODE;
};


void     mem_write_b_space(cpu_space_t *cpu, uint32_t addr, uint8_t val){
    if (addr & 0x1) { 
        fprintf(stderr, "ALIGNMENT FAULT : SW at 0x%08x not word-aligned\n", addr);
        exit(1);
    }
    if ((addr/4) >= MEM_WORDS) { 
        fprintf(stderr, "MEMORY FAULT : WRITE_B at 0x%08x out of range\n", addr);
        exit(1);
    }

    // read existing full word
    uint64_t existing = cpu -> mem_protected[addr/4];
    uint32_t data = (uint32_t) (existing & 0xFFFFFFFF);
    uint8_t old_ecc = (uint8_t) (existing >> 32);
    bool corrected =false, detected = false;
    data = edac_decode(data, old_ecc, &corrected, &detected);
    if(corrected) cpu -> edac_corrections++;
    if(detected) cpu -> edac_detections++;

    uint32_t shift  = (addr & 0x3) * 8;
    uint32_t mask = 0xFF << shift; 
    data = (data & mask) | ((uint32_t) val << shift);

    uint8_t ecc = edac_encode(data);
    cpu -> mem_protected[addr/4] = ((uint64_t) ecc << 32) | data;
    cpu -> cycles += CYCLES_EDAC_ENCODE;
};

uint32_t mem_read_w_space (cpu_space_t *cpu, uint32_t addr){
    if (addr & 0x3) { 
        fprintf(stderr, "ALIGNMENT FAULT : LW at 0x%08x not word-aligned\n", addr);
        exit(1);
    }
    if ((addr/4) >= MEM_WORDS) { 
        fprintf(stderr, "MEMORY FAULT : READ_W at 0x%08x out of range\n", addr);
        exit(1);
    }

    uint64_t word = cpu -> mem_protected[addr/4];
    uint32_t data = (uint32_t) (word& 0xFFFFFFFF); // [31:0]
    uint8_t ecc = (uint8_t)(word >> 32); // [38:32]
    bool corrected = false; 
    bool detected = false; 

    uint32_t result = edac_decode(data, ecc, &corrected, &detected);
    
    if (corrected) cpu -> edac_corrections ++;
    if (detected) cpu -> edac_detections++;

    cpu-> cycles += CYCLES_EDAC_DECODE;
    return result; 
};


uint16_t mem_read_h_space(cpu_space_t *cpu, uint32_t addr){
    if (addr & 0x1) { 
        fprintf(stderr, "ALIGNMENT FAULT : SW at 0x%08x not halfword-aligned\n", addr);
        exit(1);
    }
    if ((addr/4) >= MEM_WORDS) { 
        fprintf(stderr, "MEMORY FAULT : WRITE_W at 0x%08x out of range\n", addr);
        exit(1);
    }
    uint32_t word = cpu -> mem_protected[addr/4];
    uint32_t shift = (addr & 0x2) * 8; // shift 0 or 16
    return (uint16_t) (word >> shift); // upper or lower half left 

}


uint8_t mem_read_b_space(cpu_space_t *cpu, uint32_t addr){
    if ((addr/4) >= MEM_WORDS) { 
        fprintf(stderr, "MEMORY FAULT : WRITE_W at 0x%08x out of range\n", addr);
        exit(1);
    }
    uint32_t word = cpu -> mem_protected[addr/4];
    uint32_t shift = (addr & 0x3); // 0, 8, 16, 24 bits 
    return (uint8_t) (word >> shift);

}

void cpu_space_reset(cpu_space_t *cpu){
    memset(cpu-> regs, 0, sizeof(cpu->regs)); // 3 * 32
    cpu -> pc = 0; 
    cpu -> instrs = 0; 
    cpu -> cycles = 0;
    cpu-> halted = false; 

    cpu-> edac_corrections =0; 
    cpu-> edac_detections = 0;
    cpu-> tmr_corrections = 0;
    // mem_protected remains the same 

};


void load_hex_space(cpu_space_t *cpu, const char *filename){
    FILE *f = fopen(filename, "r");
    if (!f) { 
        perror("load_hex_space : cannot open file"); exit(1);
    }

    memset(cpu-> mem_protected, 0, sizeof(cpu->mem_protected));

    uint32_t addr = 0 ;
    char line[128];

    while (fgets(line, sizeof(line), f )) {
        if (line[0] == '\n' || line[0] == '\r') continue;
        if (line[0] == '@') { 
            addr = (uint32_t) strtoul (&line[1], NULL, 16); // convert the text after @ into a hexadecimal integer. (strtoul = string to unsigned long)
        } else {
            uint32_t word = (uint32_t) strtoul(line, NULL, 16);
            if (addr < MEM_WORDS) { 
                uint8_t ecc = edac_encode(word);
                cpu-> mem_protected[addr] = ((uint64_t) ecc << 32 | word);
                addr ++;
            } else fprintf(stderr, "load_hex_space : address 0x%08x exceeds MEM_WORDS\n", addr);
        }
    }

    fclose(f);
};