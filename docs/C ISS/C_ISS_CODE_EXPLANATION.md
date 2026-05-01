# C ISS — Code Explanation
This document explains every file in the simulator, line by line.  
Intended as a **personal study reference** not for GitHub readers.

---

## Table of Contents
 
1. [rv32i.h — the header](#rv32ih--the-header)
2. [memory.c — hex loader and memory access](#memoryc--hex-loader-and-memory-access)
3. [execute.c — fetch, decode, execute](#executec--fetch-decode-execute)
4. [trace.c — instruction printing](#tracec--instruction-printing)
5. [main.c — entry point and run loop](#mainc--entry-point-and-run-loop)

---

## rv32i.h — the header

---
 
## memory.c — hex loader and memory access

```c
void load_hex(cpu_t * cpu, const char *filename)
```

- opens a file and reads it line by line 
- converts text (hex) to numbers 
- stores them into `cpu -> mem`
---

```c
static void check_addr(uint32_t addr, uint32_t size, const char *op)

uint32_t mem[MEM_WORDS];
uint32_t byte_limit = MEM_WORDS * 4; // converts words to bytes 
```
- memory is stored as **words**
- 1 word = **4 bytes** (i.e. `uint32_t`)
- addressees (`addr`) are in **bytes** but memory array is in **words**
- `static` prevents other files from calling it (only visible in this `.c` file)

```c
check_addr(100, 4, "LOAD");
```
- start at byte 100
- read 4 bytes 
- OK if within memory

```c
uint32_t mem_read_w(cpu_t *cpu, uint32_t addr)
```
- Reads a 32-bit word (4 bytes) from memory at a given byte address

```c
if (addr & 0x3) // if address is NOT divisible by 4 then error 
```
- `0x3` = `00000011` : it keeps only the last two bits 
- 4-byte word must start at addresses : 0, 4, 8, ...
- these are multiples of 4 : last 2 bits == `00`


```c
uint32_t shift = (addr & 0x2) * 8 // checks bit 1
```
- lower half -> shift = 0
- upper half -> shift = 16 

```c
(word >> shift)
```
- move desired 16 bits to the right 


```c

uint8_t mem_read_b(cpu_t *cpu, uint32_t addr) 
```
- `0x3 = 00000011` → checks last 2 bits

    | addr | binary | addr & 0x3 | shift (bits) |
    |------|--------|------------|--------------|
    | 0    | 00     | 0          | 0            |
    | 1    | 01     | 1          | 8            |
    | 2    | 10     | 2          | 16           |
    | 3    | 11     | 3          | 24           |


---

## execute.c — fetch, decode, execute

`int32_t` vs `uint32_t`
- both are 32-bit integers 
- signed vs unsigned 
- use `int32_t` to extract immediates from the instruction 


RISCV decoding 
- `funct3` = 3-bit field inside the instruction
- select which exact operation to perform
- same opcode, different `funct3` = different behaviour
- e.g. opcode = LOAD, instructions = `lb`, `lh`, `lw`, ...
- `funct3` = main selector, `funct7` = extra detail (refinement)   


```c
cpu->cycles
```
- access the `cycles` field inside the **CPU struct**

```c
case OP_R : cpu -> cycles += CYCLES_ALU; break;
```
- add some value to the `cycles` counter

```c
static void add_cycles(cpu_t *cpu, uint32_t op, uint32_t f3) {
    (void) f3; // not using f3, don't warn it 
}
```
- i'm intentionally not using `f3`
- casts `f3` to `void` → result is ignored

```c
switch (f3) {
    case 0x0: ...
    case 0x1: ...
    // no match
}
```
- if `f3` matches none of the cases: 
    - the `switch` block is skipped entirely 
    - execution continues after the closing `}`
- if `result` was not initialised before then `result` contains garbage 
- if `result` was initialised, then it just keeps its previous value (same as in SystemVerilog)

```c
case OP_JAL: {
    uint32_t ret = pc + 4;
    cpu->pc = (uint32_t)((int32_t)pc + imm_j(instr));
    if (rd) cpu->regs[rd] = ret;
    break; 
}
```
- save return address `ret` : where to come back after the jump 
- new PC = current PC + offset 
- only store if `rd != 0`
    - if `rd` is 0, `x0` is always 0

```assembly 
main:
    addi a0, x0, 5      # argument = 5
    jal x1, func        # call func
    addi a0, a0, 1      # runs AFTER return

    # program end...


func:
    addi a0, a0, 10     # do something
    jalr x0, x1, 0      # return to caller
```
---

## trace.c — instruction printing


```c
static const char *abi_name[32] = {
    "zero", "ra", "sp", "gp", "tp",
    "t0",   "t1", "t2",
    "s0",   "s1",
    "a0",   "a1", "a2", "a3", "a4", "a5", "a6", "a7",
    "s2",   "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11",
    "t3",   "t4", "t5", "t6"
};
```
- these are RISCV registers' name (H&H Table B.4)

```c
static void decode_mnemonic(uint32_t instr, uint32_t pc, char *buf, size_t bufsz)
```
```assembly 
addi a0,a1,10
lw t0,4(sp)
jal ra,0x80000020
```
---

## main.c — entry point and run loop

```c
int main(int argc, char *argv[])
```
- `argc` = number of arguments
- `argv` = array of strings (arguments)


```c
 if (strcmp(argv[i], "--trace") == 0)
```
- string compare function from `<string.h>`
- returns `0` : strings are equal 
- returns < 0 : the formal < the latter string

```c
if (++i >= argc) usage(argv[0]); // printing 
max_instr = (uint64_t)atoll(argv[i]);
```
- `++i` → increment `i` first then compare with `argc`
    - `argv[1] = "--max"` and `argv[2] = "1000"`
- `atoll` converts string to number

```c
else if (argv[i][0] == '-') // argv[0] = "./sim"
```
- does this argument start with `-`

---
## Result 

```
./sim --trace tests/test_all.hex
Instructions retired : 14      ← 15 instructions in file, 1 was skipped (branch)
Cycles               : 53      ← total FSM states across all instructions
IPC                  : 0.2642  ← instructions per cycle
CPI                  : 3.7857  ← cycles per instruction (average)
```

### What is Dhrystone?
Dhrystone is a benchmark program — a standard test program that the whole industry uses to measure CPU performance. It was written in 1984 and is still used today because it's small, simple, and well understood.
It's designed to represent "typical" software workloads. When you run it and get an IPC number, that number is comparable to other processors that have also run Dhrystone. That's the point — it's a common reference.
Your test_all.hex is 14 hand-written instructions. That's enough to verify correctness but it's too small to be a meaningful performance number. Dhrystone runs thousands of instructions with a realistic mix of load/store/branch/ALU — the IPC you get from it is the one that goes on your CV.