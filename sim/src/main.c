#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "rv32i.h"
static void print_regs(cpu_t *cpu) {
    printf("\n--- Register File ---\n");
    for (int i = 0; i < 32; i++) {
        printf("x%02d = 0x%08X", i, cpu->regs[i]);
        if ((i & 3) == 3) printf("\n");   // 4 per line
        else              printf("  ");
    }
}

static void print_stats(cpu_t *cpu) {
    printf("\n--- Simulation Stats ---\n");
    printf("Instructions retired : %llu\n", (unsigned long long)cpu->instrs);
    printf("Cycles               : %llu\n", (unsigned long long)cpu->cycles);

    if (cpu->instrs > 0) {
        double ipc = (double)cpu->instrs / (double)cpu->cycles;
        double cpi = (double)cpu->cycles / (double)cpu->instrs;
        printf("IPC                  : %.4f\n", ipc);
        printf("CPI                  : %.4f\n", cpi);
    }
}

static void usage(const char *prog) {
    fprintf(stderr,
        "Usage: %s [options] program.hex\n"
        "\n"
        "Options:\n"
        "  --trace          print one line per instruction (Tarmac style)\n"
        "  --max N          stop after N instructions (default: 10000000)\n"
        "  --mode multicycle  cycle counting mode (default, only mode for now)\n"
        "\n"
        "Example:\n"
        "  %s --trace tests/add_test.hex\n"
        "  %s --max 5000000 dhrystone.hex\n",
        prog, prog, prog);
    exit(1);
}

int main(int argc, char *argv[]){
    const char *hexfile = NULL; 
    bool trace = false ;
    uint64_t max_instr= 10000000ULL;  // 10M instructions default

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--trace") == 0) {trace = true;}
        else if (strcmp(argv[i], "--max") == 0) {
            if (++i >= argc) usage(argv[0]);
            max_instr = (uint64_t)atoll(argv[i]);
        } else if (strcmp(argv[i], "--mode")==0){
            if (++i >= argc) usage(argv[0]);
            if (strcmp(argv[i], "multicycle") != 0) {
                fprintf(stderr, "Unknown mode '%s'. Only 'multicycle' supported.\n", argv[i]);
                exit(1);
            }
            // will add other modes later 

        } else if (argv[i][0] == '-') { 
            fprintf(stderr, "Unknown option: %s\n", argv[i]);
            usage(argv[0]);
        } else {hexfile = argv[i];}
    }

    if (!hexfile) usage(argv[0]);


    cpu_t cpu; 
    memset(&cpu, 0, sizeof(cpu));
    cpu.mode = MODE_MULTICYCLE;

    load_hex(&cpu, hexfile);
    cpu_reset(&cpu);

    printf("[ISS] Loaded: %s\n", hexfile);
    printf("[ISS] Mode  : multicycle\n");
    if (trace) printf("[ISS] Trace : on\n");
    printf("\n");

    while (!cpu.halted && cpu.instrs < max_instr) { 
        step(&cpu, trace);
    }

    if (cpu.instrs >= max_instr) {
        printf("\n[ISS] Reached max instruction limit (%llu)\n",
        (unsigned long long)max_instr);
    }

    print_regs(&cpu);
    print_stats(&cpu);

    return 0;

}