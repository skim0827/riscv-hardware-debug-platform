## Yosys with SystemVerilog 
Yosys's built-in frontend does not support **package**, it's one of the SystemVerilog features that was never implemented. The fix is to run `sv2v` first to flatten everything into plain Verilog, then hand that to Yosys.

## Haskell Stack
**Stack** is a build tool for the Haskell programming language. We need this because `sv2v` is written in **Haskell**.
- download dependencies
- install the correct compiler (GHC)
- build the project
- produce an executable

`sv2v` is not a ready program yet, it’s source code. So, we need **Stack** to compile it into a binary.

when we do `stack build`, Stack does downloads a specific Haskell compiler (GHC), downloads all libraries, compiles the source code, produces `~/sv2v/bin/sv2v` (i.e. final file is the real executable we want).

```bash
cd ~/sv2v
stack update
make
./bin/sv2v --version
sudo cp bin/sv2v /usr/local/bin/ # install it system-wise 
sv2v --version
```

## Why Yosys ? 
Yosys is a hardware synthesis tool. It takes the RTL (Verilog/SystemVerilog) and converts it into a gate-level netlist.

```
RTL (Verilog/SystemVerilog)
        ↓
   Yosys (synthesis)
        ↓
Gate-level netlist
        ↓
Place & Route (FPGA / ASIC tools)
        ↓
Bitstream / chip layout
```

**Yosys** is widely used because it provides a free and **open-source** alternative to proprietary synthesis tools such as Synopsys Design Compiler, Cadence Genus, and Xilinx Vivado, making it especially attractive for academic, research, and experimental projects like RISC-V-based designs. Its integration within open hardware ecosystems—such as OpenLane for ASIC design, nextpnr for FPGA implementation, and SymbiYosys—enables fully open-source design flows from RTL to implementation. Additionally, Yosys offers powerful **scripting** capabilities, allowing users to automate synthesis processes through simple commands (e.g., reading Verilog, synthesizing, and exporting netlists), which is particularly useful for continuous integration and testing environments. Beyond synthesis, it also serves as a valuable tool for debugging and analysis, enabling designers to inspect generated circuits, evaluate optimizations, and better understand how high-level RTL descriptions are translated into low-level hardware structures.


| Level                      | Tool                  | Needed for your CV?                                              |
|----------------------------|-----------------------|-------------------------------------------------------------------|
| Synthesis (tech-independent) | Yosys                 | ✅ Yes — do this                                                   |
| FPGA implementation        | Vivado / Quartus      | Only if you have a board and want "runs at X MHz on Artix-7"       |
| ASIC place & route         | OpenROAD / OpenLane   | Only if targeting tapeout (e.g. TinyTapeout)                      |
| Timing closure, STA        | OpenSTA               | Only if you have a real target process                            |

## HOW YOSYS WORKS (SIMPLE EXPLICATION)

**Yosys** is a synthesis tool that transforms a **Verilog** hardware description into a structural representation of digital logic through a sequence of well-defined compiler-like steps. It first **parses** the input code to understand the design hierarchy, signals, and assignments, building an internal representation of the circuit. It then lowers high-level behavioural constructs into simpler forms, for example by converting conditional statements into explicit multiplexer-based data flow. In the next stage, procedural blocks such as `always` statements are translated into actual hardware elements, where combinational logic is expressed as **networks** of wires and multiplexers, and sequential logic is implemented using flip-flops. After this transformation, Yosys applies **optimisation** passes to simplify the resulting circuit by removing redundant logic and reducing complexity. Finally, it performs **technology mapping**, where generic logic is converted into concrete hardware primitives such as logic gates or FPGA lookup tables. Through this progressive rewriting process, Yosys systematically converts high-level RTL descriptions into a netlist that represents the equivalent hardware structure.

## Results 

```
=== system_top ===

   Number of wires:              27541
   Number of wire bits:          35018
   Number of public wires:         392
   Number of public wire bits:    7869
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:              34000
     $_ANDNOT_                     741
     $_AND_                       4208
     $_AOI3_                       133
     $_AOI4_                       486
     $_DFF_PN0_                   2400
     $_DFF_PN1_                      3
     $_DFF_P_                     4282
     $_MUX_                      15053
     $_NAND_                       862
     $_NOR_                         88
     $_NOT_                       1416
     $_OAI3_                       310
     $_OAI4_                      1445
     $_ORNOT_                      222
     $_OR_                        2249
     $_XNOR_                        23
     $_XOR_                         79


```

```
=== cpu ===

   Number of wires:              22156
   Number of wire bits:          28168
   Number of public wires:         256
   Number of public wire bits:    6206
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:              27480
     $_ANDNOT_                     365
     $_AND_                       4104
     $_AOI3_                        69
     $_AOI4_                       568
     $_DFF_PN0_                   1265 // Register file (32×32) + pipeline regs
     $_DFF_PN1_                      1 // Register file (32×32) + pipeline regs
     $_DFF_P_                     4096  // Memory array (128×32)
     $_MUX_                      12717
     $_NAND_                       304
     $_NOR_                         47
     $_NOT_                       1042
     $_OAI3_                       195
     $_OAI4_                       900
     $_ORNOT_                      105
     $_OR_                        1604
     $_XNOR_                        17
     $_XOR_                         81

```

| Scope                                      | Cells  | FFs   |
|--------------------------------------------|--------|-------|
| Full system (core + debug + JTAG)          | 34,000 | 6,685 |
| CPU core only                              | 27,480 | 5,362 |
| **Debug overhead**                         | 6,520  | 1,323 |
| Memory array (FF-mapped)                   | —      | 4,096 |
| Actual architectural state (regfile + pipeline) | —      | 1,266 |


- **Cells** = all hardware elements in your design
- **FFs** (flip-flops) = only the sequential storage elements
- FFs are a subset of cells

In Yosys, a **cell** is any primitive element after synthesis, such as:

- logic gates (AND, OR, NOT)
- multiplexers
- adders
- comparators
- flip-flops
- memories (sometimes expanded into FFs)

Basically: everything that becomes hardware

## Space Application 
In radiation-prone environments such as space, reducing the total number of **cells** in a design can slightly lower the probability of radiation-induced faults, as a smaller circuit presents fewer physical targets for particle interactions. However, not all cells are equally critical. **Flip-flops (FFs)**, which store the system state, are significantly more sensitive to radiation effects such as **Single Event Upsets (SEUs)**, where a bit flip can directly corrupt computation. In contrast, combinational logic cells may experience transient glitches (**Single Event Transients**), but these only become problematic if they are captured by sequential elements. Therefore, the number and protection of **flip-flops** are generally more important than the overall cell count when evaluating radiation robustness.

In practice, space-grade processor design does not primarily rely on minimising cell count to achieve reliability. Instead, it emphasizes **fault tolerance techniques** that often increase hardware complexity. Methods such as **Triple Modular Redundancy** (TMR), **error-correcting codes** (ECC), and **periodic state scrubbing** are widely used to detect and correct radiation-induced errors. These approaches deliberately add **redundancy** and thus increase the number of cells, but they significantly improve system resilience. As a result, there is a fundamental **trade-off between minimising area and maximising robustness**, with space applications prioritising reliability over compactness.


**TMR** (Triple Modular Redundancy) is pure hardware. you replicate a block three times and add a voter that selects the majority result. If one copy is upset by radiation, the other two outvote it. This is widely used for flip-flops and sometimes for entire pipelines. **ECC** (Error Correcting Codes) is not just “software”. It’s mainly hardware logic (encoders/decoders around memories like SRAM, caches, register files). Software may assist (e.g., handling corrected/uncorrected error interrupts), but the correction itself (e.g., Hamming/SECDED) is typically done in hardware on every read/write.

**Scrubbing** means periodically reading and correcting stored state so that accumulated errors don’t build up. For example, a memory scrubber will cycle through memory, read each word, use ECC to fix any single-bit errors, and write back the corrected value. In systems using TMR, scrubbing can also “repair” a faulty replica by rewriting it with the voted-correct state. This is essential because even with protection, errors can accumulate over time.

**Lockstep** is another redundancy technique at the processor level. Two (or more) cores run the same instructions in parallel, and their outputs are continuously compared. If they diverge, a fault is detected and the system can trigger recovery (reset, rollback, or switch to a spare). Unlike TMR, lockstep typically detects errors rather than correcting them on the fly (unless combined with additional mechanisms), but it’s effective and often cheaper than triplication.