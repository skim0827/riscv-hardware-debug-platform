# C Instruction Set Simulator

A lightweight RV32I instruction set simulator written in C. Built alongside a multicycle RV32I RTL core in SystemVerilog as an independent reference model.

---

## Motivation

### 1. RTL cross-validation

The simulator runs the same `.hex` files as the RTL testbench. After each instruction, both produce a trace:

```
PC=00000000 | 00500193 | addi gp,zero,5
PC=00000004 | 00300213 | addi tp,zero,3
PC=00000008 | 004182B3 | add t0,gp,tp
```

If the ISS trace and the RTL simulation trace agree instruction-by-instruction, the RTL is **functionally** correct. This is an **independent software reference** that the hardware must match.

### 2. Cycle-accurate IPC measurement

The simulator models the multicycle FSM from the RTL exactly — each pipeline state costs one cycle:

| Instruction type | States | Cycles |
|---|---|---|
| R / I ALU | FETCH + DECODE + EXECUTE + WB | 4 |
| Load | FETCH + DECODE + MEMADR + MEMREAD + MEMWB | 5 |
| Store | FETCH + DECODE + MEMADR + MEMWRITE | 4 |
| Branch | FETCH + DECODE + BEQ | 3 |
| JAL / JALR | FETCH + DECODE + EXECUTE + WB | 4 |

Running **Dhrystone** through the simulator produces a concrete **IPC number** that reflects the real cost of the multicycle architecture before FPGA bring-up is complete.

---


## Code explanation
 
For a detailed walkthrough of every file : see [C_ISS_CODE_EXPLANATION.md](C_ISS_CODE_EXPLANATION.md).
 
---


## Usage

```bash
make
./sim program.hex                        # run silently, print registers + IPC
./sim --trace program.hex                # print one line per instruction
./sim --max 5000000 dhrystone.hex        # cap at 5M instructions
```

## Build

```bash
gcc -Wall -Wextra -Iinclude src/*.c -o sim
```
Or simply:
```bash
make
```
