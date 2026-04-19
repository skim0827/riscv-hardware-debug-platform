# Testing and Verification Guide

Comprehensive guide to building, running, and writing tests for the RISC-V hardware debug platform.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Test Structure](#test-structure)
3. [Running Tests](#running-tests)
4. [Understanding Coverage](#understanding-coverage)
5. [Writing Tests](#writing-tests)
6. [Waveform Inspection](#waveform-inspection)
7. [Debugging Failures](#debugging-failures)

---

## Quick Start

### One-Minute Test Run

```bash
# Build and execute the DTM (Debug Transport Module) test
make coverage suite=dtm tb=tb_dtm_top

# View the coverage report
make coverage_report

# See which lines weren't covered
make coverage_view

# Clean build artefacts for a fresh start
make clean
```

---

## Test Structure

### Directory Layout

```
tb/
├── core/          # CPU core module tests
│   ├── tb_alu.sv
│   ├── tb_alu_decoder.sv
│   ├── tb_cpu_top.sv
│   ├── tb_instr_decoder.sv
│   ├── tb_program_counter.sv
│   └── tb_regfile.sv
├── debug/         # Debug module tests
│   └── tb_debug_module.sv
├── dtm/           # JTAG DTM tests
│   └── tb_dtm_top.sv
├── jtag/          # JTAG TAP controller tests
│   └── tb_tap_fsm.sv
└── system/        # Integration tests
    └── tb_system.sv
```

### Test Naming Convention

- **Test files**: `tb_<module_name>.sv`
- **Test tasks**: `test_<functionality>()` (e.g., `test_add_operation()`, `test_halt_hart()`)
- **Helper tasks**: `helper_<action>()` (e.g., `helper_clock_pulse()`, `helper_reset()`)

### Test Components

A typical SystemVerilog testbench includes:

```systemverilog
`timescale 1ns/1ps

module tb_module_name;
    import dmi_pkg::*;
    
    // ===== TESTBENCH SIGNALS =====
    logic clk, rst_n;
    logic [31:0] data_in, data_out;
    logic enable, valid;
    
    // ===== TEST COUNTERS =====
    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;
    
    // ===== INSTANTIATE DUT =====
    module_under_test u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_out(data_out),
        .enable(enable),
        .valid(valid)
    );
    
    // ===== CLOCK GENERATION =====
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;  // 20ns period = 50 MHz
    end
    
    // ===== HELPER TASKS =====
    task automatic reset_dut();
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(5) @(posedge clk);
    endtask
    
    task automatic assert_equal(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string test_name
    );
        if (actual == expected) begin
            $display("[PASS] %s", test_name);
            pass_count++;
        end else begin
            $display("[FAIL] %s – Expected: 0x%08x, Got: 0x%08x", 
                     test_name, expected, actual);
            fail_count++;
        end
        test_count++;
    endtask
    
    // ===== TEST PROCEDURES =====
    task automatic test_basic_operation();
        $display("TEST: Basic Operation");
        reset_dut();
        
        @(posedge clk);
        data_in = 32'hDEADBEEF;
        enable = 1'b1;
        
        @(posedge clk);
        assert_equal(data_out, 32'hDEADBEEF, "Data passes through");
        
        enable = 1'b0;
    endtask
    
    // ===== MAIN SIMULATION =====
    initial begin
        $display("╔═══════════════════════════════════╗");
        $display("║  MODULE UNDER TEST SIMULATIONS    ║");
        $display("╚═══════════════════════════════════╝");
        
        // Run all tests here
        test_basic_operation();
        
        $display("");
        $display("╔═══════════════════════════════════╗");
        $display("║         TEST SUMMARY             ║");
        $display("╚═══════════════════════════════════╝");
        $display("Total Tests:  %0d", test_count);
        $display("Passed:       %0d", pass_count);
        $display("Failed:       %0d", fail_count);
        
        #100 $finish;
    end
endmodule
```

---

## Running Tests

### Basic Test Execution

**Syntax**:
```bash
make coverage suite=<suite> tb=<testbench>
```

**Parameters**:

- `suite` – Test category: `core`, `debug`, `dtm`, `jtag`, or `system`
- `tb` – Testbench file (without `.sv` extension): `tb_alu`, `tb_dtm_top`, etc.

### Common Test Commands

```bash
# ===== CPU Core Tests =====
make coverage suite=core tb=tb_alu
make coverage suite=core tb=tb_regfile
make coverage suite=core tb=tb_cpu_top

# ===== Debug Module Tests =====
make coverage suite=debug tb=tb_debug_module

# ===== JTAG Tests =====
make coverage suite=jtag tb=tb_tap_fsm

# ===== DTM Tests =====
make coverage suite=dtm tb=tb_dtm_top

# ===== System Integration Tests =====
make coverage suite=system tb=tb_system
```

### Build Process

When you run `make coverage suite=<suite> tb=<testbench>`:

1. **Verilator elaboration**: Reads SystemVerilog files specified in `filelist.f`
2. **RTL simulation**: Executes the testbench and generates `.vcd` waveform file
3. **Coverage collection**: Generates `coverage.dat` file
4. **Report generation**: Converts `coverage.dat` to readable `coverage.txt`
5. **Executable runs**: Simulates and produces console output

**Output files**:

- `obj_dir/V<testbench>` – Compiled simulation executable
- `dump.vcd` – Waveform file (for GTKWave viewer)
- `coverage.dat` – Binary coverage database
- `coverage.txt` – Human-readable coverage report

### Partial/Quick Builds

```bash
# Just compile (don't run)
make core tb=tb_alu

# Run existing executable without recompiling
make run tb=tb_alu

# Just build the executable
verilator --sv --trace --coverage --binary -f filelist.f tb/core/tb_alu.sv --top-module tb_alu

# Run with custom Verilator flags
verilator --sv -Wall -Wno-UNUSED --trace --coverage --binary -f filelist.f tb/core/tb_alu.sv
```

---

## Understanding Coverage

### What is Coverage?

Coverage metrics show which lines of code (HDL) were executed during simulation:

- **Line coverage**: Did the simulator execute this line?
- **Conditional coverage**: Were all branches of if/case statements taken?
- **Expression coverage**: Were all operand combinations evaluated?

### Viewing Coverage Reports

**Generate report**:
```bash
make coverage_report
```

**Example output**:

```
╔════════════════════════════════════════════════════════╗
║                  COVERAGE REPORT SUMMARY               ║
╚════════════════════════════════════════════════════════╝

Total Coverage Points:     1234
├─ Covered (1+ exec):      1156 (93%)
└─ NOT Covered (0 exec):   78   (6%)

Overall Coverage:          93%

📊 Coverage data saved to coverage.txt
```

### Finding Uncovered Code

```bash
# Show top 20 uncovered lines
make coverage_view
```

**Example output**:

```
Top 20 UNCOVERED points (0 executions):
rtl/debug/debug_module.sv:145:0' 0
rtl/debug/debug_module.sv:156:0' 0
rtl/debug/debug_module.sv:203:0' 0
```

### Improving Coverage

**Steps to increase coverage**:

1. **Identify gaps**: Run `make coverage_view` to find uncovered code
2. **Write targeted tests**: Add test cases that exercise the uncovered paths
3. **Re-run coverage**: Verify coverage improves
4. **Repeat**: Aim for >90% coverage

**Common coverage gaps**:

- **Error handling**: Paths triggered by invalid inputs or edge cases
- **Reset sequences**: Asynchronous reset conditions
- **Rare state transitions**: Debug mode corner cases
- **Boundary conditions**: Min/max values, wrap-around

---

## Writing Tests

### Test Strategy

**Layered approach** (bottom-up):

1. **Unit tests** – Individual components (ALU, register file, decoder)
2. **Integration tests** – Sub-systems (CPU, debug module)
3. **System tests** – Full platform (CPU + JTAG + debug)

### Template for New Tests

Create `tb/core/tb_my_new_module.sv`:

```systemverilog
`timescale 1ns/1ps

module tb_my_new_module;
    import riscv_pkg::*;
    
    // ===== SIGNALS =====
    logic clk, rst_n;
    logic [31:0] result;
    
    // ===== TEST COUNTERS =====
    int test_count = 0, pass_count = 0, fail_count = 0;
    
    // ===== DUT INSTANTIATION =====
    my_module u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .result(result)
    );
    
    // ===== CLOCK =====
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
    // ===== RESET =====
    task automatic reset_device();
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
    endtask
    
    // ===== ASSERTIONS =====
    task automatic assert_value(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string name
    );
        if (actual == expected) begin
            $display("[PASS] %s: 0x%08x", name, actual);
            pass_count++;
        end else begin
            $display("[FAIL] %s: Expected 0x%08x, Got 0x%08x", 
                     name, expected, actual);
            fail_count++;
        end
        test_count++;
    endtask
    
    // ===== TEST PROCEDURES =====
    task automatic test_initialization();
        $display("\n=== TEST: Initialization ===");
        reset_device();
        assert_value(result, 32'h0, "Reset clears result");
    endtask
    
    // ===== MAIN STIMULUS =====
    initial begin
        $display("\n╔═════════════════════════════════╗");
        $display("║  MY MODULE TEST SUITE           ║");
        $display("╚═════════════════════════════════╝\n");
        
        test_initialization();
        
        $display("\n╔═════════════════════════════════╗");
        $display("║        TEST SUMMARY             ║");
        $display("╚═════════════════════════════════╝");
        $display("Total Tests:  %0d", test_count);
        $display("Passed:       %0d", pass_count);
        $display("Failed:       %0d (%.1f%% pass rate)\n", 
                 fail_count, (pass_count * 100.0 / test_count));
        
        #100 $finish;
    end
    
endmodule
```

### Test Procedure Examples

#### Example 1: ALU Test

```systemverilog
task automatic test_add();
    logic [31:0] srcA, srcB, result;
    
    $display("\nTesting ADD operation");
    
    @(posedge clk);
    srcA = 32'h0000_0005;
    srcB = 32'h0000_0003;
    // Set ALU control to ADD
    
    @(posedge clk);
    result = alu_result;
    assert_value(result, 32'h0000_0008, "5 + 3 = 8");
endtask
```

#### Example 2: Debug Module Test

```systemverilog
task automatic test_halt_resume();
    $display("\nTesting HALT and RESUME");
    
    // Write DMCONTROL with haltreq=1
    @(posedge clk);
    dmi_we = 1;
    dmi_addr = DMI_DMCONTROL;
    dmi_wdata = 32'h8000_0001;  // haltreq=1
    
    @(posedge clk);
    dmi_we = 0;
    repeat(10) @(posedge clk);
    
    // Read DMSTATUS and check anyhalted
    dmi_re = 1;
    dmi_addr = DMI_DMSTATUS;
    @(posedge clk);
    assert_value(dmi_rdata[0], 1'b1, "Hart halted flag set");
    
    dmi_re = 0;
endtask
```

#### Example 3: JTAG Sequence Test

```systemverilog
task automatic test_jtag_idcode();
    $display("\nTesting JTAG IDCODE read");
    
    // Shift IDCODE instruction into IR
    shift_ir(5'h01);
    
    // Shift 32-bit IDCODE out of DR
    logic [31:0] idcode;
    shift_dr(32'h0, 32, idcode);
    
    assert_value(idcode, 32'h1234_5678, "IDCODE matches");
endtask

task automatic shift_ir(input logic [4:0] ir_value);
    integer i;
    @(posedge tck);
    capture_ir = 1;
    @(posedge tck);
    capture_ir = 0;
    
    @(posedge tck);
    shift_ir = 1;
    for (i = 0; i < 5; i++) begin
        @(posedge tck);
        tdi = ir_value[i];
    end
    shift_ir = 0;
    
    @(posedge tck);
    update_ir = 1;
    @(posedge tck);
    update_ir = 0;
endtask
```

### Best Practices for Tests

1. **Isolate tests**: Each test should be independent (no side effects)
2. **Reset between tests**: Always call reset at test start
3. **Use descriptive names**: `test_dmi_write_halt_request` is better than `test_1`
4. **Document expectations**: Add comments explaining what's being tested and why
5. **Check multiple scenarios**: Test happy path + edge cases + error conditions
6. **Use consistent assertions**: Apply the same assertion format throughout
7. **Measure coverage**: Regularly check and aim to improve coverage

### Test Coverage Targets

| Module | Target Coverage | Rationale |
|--------|-----------------|-----------|
| ALU | >95% | Core computational unit, simple control flow |
| Register File | >90% | Straightforward read/write, minimal logic |
| CPU Core (top) | 80–85% | Complex state machine, harder to cover all paths |
| Debug Module | >85% | Critical for debugging, but has many register fields |
| JTAG/TAP | >80% | Protocol-driven, many rare states |

---

## Waveform Inspection

### Generating Waveforms

Waveforms are generated automatically when Verilator is run with `--trace`:

```bash
# This is already included in the Makefile
make coverage suite=core tb=tb_alu
# Creates: dump.vcd
```

### Viewing Waveforms with GTKWave

```bash
# Install GTKWave (Ubuntu/Debian)
sudo apt-get install gtkwave

# Open waveform
gtkwave dump.vcd
```

### Waveform Navigation Tips

- **Zoom**: Click and drag timeline, or use scroll wheel
- **Pan**: Middle-click and drag
- **Search**: Ctrl+F to find signals
- **Bookmarks**: Mark important time points
- **Radix**: Right-click signal → change from binary to hex/decimal

### What to Look For

- **Clock edges**: Verify data changes on expected clock edges
- **Control signals**: Track FSM state transitions
- **Data values**: Check calculations are correct
- **Timing violations**: Look for setup/hold issues
- **Reset sequence**: Confirm reset clears all registers

### Common Waveform Patterns

**Successful write operation**:
```
clk:    ─┬─┬─┬─┬─┬─┬─
write:  ─┼─┴─┬───────  (strobed before clock edge)
addr:   ─┼───●───────  (valid before write strobe)
data:   ─┼───●───────  (valid before write strobe)
```

**Clock gating**:
```
clk:     ─┬─┬─┬─┬─┬─┬─
enable:  ─┼─┬─┴─────∼  (synchronise to clock)
clk_en:  ─┼─┻━━━━━  (gated clock)
```

---

## Debugging Failures

### Common Issues

#### Issue 1: Test Hangs (Infinite Loop)

**Symptom**: Simulation never finishes, runs forever

**Causes**:
- Missing `$finish` statement
- Infinite `forever` loop without escape condition
- Deadlock in synchronisation between testbench and DUT

**Debug steps**:
1. Add `$stop` after key tests to break execution
2. Check for typos in signal names (unused signals remain zero)
3. Verify clock is toggling: `$monitor("clk=%b", clk);`

#### Issue 2: Assertion Failures

**Symptom**: Test fails due to value mismatch

```
[FAIL] Register write – Expected: 0x12345678, Got: 0xDEADBEEF
```

**Debug steps**:
1. Check test logic – are you setting inputs correctly?
2. Add intermediate assertions to narrow down where logic goes wrong
3. Inspect waveform at failure point
4. Verify reset state is clean

#### Issue 3: Coverage Not Improving

**Symptom**: Coverage stays flat despite adding tests

**Causes**:
- Tests aren't reaching target code
- Verilator optimised away code
- Coverage threshold too low

**Debug steps**:
1. Add `$display` statements around critical code
2. Check waveform to confirm signals are transitioning
3. Try more aggressive test cases (boundary values, rapid sequences)

#### Issue 4: Verilator Compilation Errors

```
%Error: tb/test.sv:42:5: syntax error, unexpected endtask
```

**Causes**:
- Missing semicolons
- Improper use of SystemVerilog syntax
- Type mismatches in port connections

**Debug steps**:
1. Check line 42 and surrounding context
2. Compare against working testbenches
3. Run Verilator with more verbose output: `verilator -Wall`

### Verbose Debugging

Add these to your testbench for detailed logging:

```systemverilog
// Enable message output
initial begin
    $display("Starting simulation at time %0t", $time);
end

// Monitor key signals
always @(posedge clk) begin
    $display("[%0t] state=%s, output=0x%08x", $time, state.name(), output);
end

// Trace control flow
task automatic my_test();
    $display("[my_test] Starting");
    // ... test code ...
    $display("[my_test] Finished");
endtask
```

### Using $dumpfile and $dumpvars

For selective signal dumping:

```systemverilog
initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_module);  // Dump all signals in tb_module
    $dumpon;
    
    // ... simulation ...
    
    #1000 $dumpoff;  // Stop recording after 1000ns
end
```

---

## Continuous Integration (CI)

### Recommended CI Workflow

Create `.github/workflows/test.yml` for automated testing:

```yaml
name: Hardware Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Install Verilator
        run: sudo apt-get install verilator
      
      - name: Run DTM tests
        run: make coverage suite=dtm tb=tb_dtm_top
      
      - name: Run Core tests
        run: make coverage suite=core tb=tb_cpu_top
      
      - name: Check coverage
        run: |
          coverage_pct=$(grep "Overall Coverage:" coverage.txt | awk '{print $3}')
          if (( $(echo "$coverage_pct < 80" | bc -l) )); then
            echo "Coverage too low: $coverage_pct%"
            exit 1
          fi
```

---

## Performance Tips

### Speeding Up Simulations

1. **Reduce simulation time**: Minimise `#delays` and iteration counts
2. **Disable excessive logging**: Remove `$display` from loops
3. **Use parallel builds**: `make coverage suite=core & make coverage suite=debug &`
4. **Pre-compile once**: Keep `obj_dir` between runs when code doesn't change

### Memory Constraints

- Very large testbenches (>100K lines) may cause memory issues
- Split large tests into multiple smaller testbenches
- Use `--verilator-options "-O3"` to enable optimisation

---

## Related Documentation

- See **[MODULES.md](MODULES.md)** for module signal descriptions
- See **[ARCHITECTURE.md](ARCHITECTURE.md)** for design overview
- See **[README.md](../README.md)** for build instructions

---

**Document Version**: 1.0  
**Last Updated**: April 2026  
**Status**: Complete
