# =============================================================================
# start.S — minimal RISC-V startup for fir_benchmark
#
# What this does before calling main():
#   1. Set stack pointer to top of DMEM (0x1000_0200 = 128 words × 4 + base)
#   2. Zero the BSS section (uninitialized globals)
#   3. Call main()
#   4. Loop forever if main() returns
#
# Why we need this:
#   C code expects sp to be valid before any function call.
#   Without this, the first push to the stack corrupts unknown memory.
# =============================================================================
.section .text.start
.global _start

_start:
    # 1. Set stack pointer to top of DMEM
    #    DMEM base = 0x1000_0000, size = 512 words = 2048 bytes
    #    Stack grows downward, so start at 0x1000_0800
    li   sp, 0x10000800

    # 2. Zero BSS section
    la   t0, __bss_start
    la   t1, __bss_end
bss_loop:
    bge  t0, t1, bss_done
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    bss_loop
bss_done:

    # 3. Call main
    call main

    # 4. Halt if main returns
halt:
    j    halt