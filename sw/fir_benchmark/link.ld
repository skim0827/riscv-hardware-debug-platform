/*
   link.ld — linker script for fir_benchmark
   
   IMEM: 0x0000_0000, 2048 bytes (512 words × 4)  — instructions
   DMEM: 0x1000_0000, 2048 bytes (512 words × 4)  — data + stack

   Stack pointer set to 0x1000_0800 (top of DMEM) in start.S
   Stack grows downward, so arrays in main() sit below 0x1000_0800.

   NOTE: 64 samples × 3 arrays (input, out_cpu, out_hw) × 2 bytes = 384 bytes.
   Plus stack frames for fir_cpu/fir_hw + libgcc soft-mul/div routines in IMEM.
 */
MEMORY {
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 2048
    DMEM (rw)  : ORIGIN = 0x10000000, LENGTH = 2048
}

SECTIONS {
    /* Instructions → IMEM */
    .text : {
        *(.text.start)   /* start.S first */
        *(.text*)
        *(.rodata*)      /* string literals, const arrays */
        . = ALIGN(4);
    } > IMEM

    /* Initialised globals → DMEM */
    .data : {
        . = ALIGN(4);
        *(.data*)
        . = ALIGN(4);
    } > DMEM

    /* Uninitialised globals → DMEM (zeroed by start.S) */
    .bss : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > DMEM
}