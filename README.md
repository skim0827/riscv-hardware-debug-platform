# RISC-V Hardware Debug Platform

A fully functional 32-bit RISC-V processor with external debugging capabilities, designed to demonstrate hardware architecture principles and RISC-V debugging standards (v0.13.2).

## Overview

This project implements a complete debugging platform featuring:

- **32-bit RISC-V RV32I Processor** - A multi-cycle processor supporting 32 base instructions
- **JTAG Interface** - IEEE 1149.1 compliant Test Access Port for external debugging
- **Debug Transport Module (DTM)** - Converts JTAG sequences into Debug Module Interface (DMI) transactions
- **Debug Module** - Full RISC-V external debug module with register control, abstract commands, and data registers
- **Comprehensive Test Suite** - Simulation-based verification with coverage analysis

## Features

### Processor Architecture
- **Multi-cycle Execution**: Each instruction completes through multiple sequential cycles
- **RV32I Base ISA**: 32 instructions covering R, I, S, B, J, and U-type formats
- **32 × 32-bit General Purpose Registers**
- **Simple memory subsystem** for instruction and data storage
- **Debuggable**: Halt, step, and register inspection through JTAG

### Debug Capabilities
- **Halt/Resume**: Stop processor execution for inspection
- **Register Access**: Read/write CPU registers remotely
- **Program Counter Control**: Modify execution flow
- **Program Buffer**: Execute debug programmes without modifying main memory
- **Status Monitoring**: Track hart state, instruction completion, and debug readiness

## Quick Start

### Prerequisites

Before building, ensure you have installed:
- **Verilator** (>= 5.0) - For SystemVerilog simulation
- **Make** - Build automation
- **C++ compiler** - For compiled Verilator output

**Installation** (Ubuntu/Debian):
```bash
sudo apt-get install verilator make g++
```

**Verification**:
```bash
verilator --version
```

### Building

Clone the repository:
```bash
git clone https://github.com/skim0827/riscv-hardware-debug-platform.git
cd riscv-hardware-debug-platform
```

### Running Tests

Test the entire system with:
```bash
make coverage suite=dtm tb=tb_dtm_top
```

Test individual components:
```bash
# Test the ALU
make coverage suite=core tb=tb_alu

# Test the Debug Module
make coverage suite=debug tb=tb_debug_module

# Test JTAG  
make coverage suite=jtag tb=tb_tap_fsm
```

### Viewing Results

Display coverage report:
```bash
make coverage_report
```

View uncovered lines:
```bash
make coverage_view
```

Clean build artefacts:
```bash
make clean
```

## Project Structure

```
riscv-hardware-debug-platform/
├── README.md                 # This file
├── Makefile                  # Build automation
├── filelist.f                # Verilator file list
├── rtl/                      # RTL design files
│   ├── core/                 # CPU core implementation
│   ├── debug/                # Debug module
│   ├── dtm/                  # JTAG Debug Transport Module
│   ├── jtag/                 # JTAG TAP controller
│   ├── package/              # SystemVerilog packages
│   └── system/               # System integration
├── tb/                       # Test benches
│   ├── core/                 # CPU core tests
│   ├── debug/                # Debug module tests
│   ├── dtm/                  # DTM tests
│   ├── jtag/                 # JTAG tests
│   └── system/               # Integration tests
└── docs/                     # Documentation
    ├── ARCHITECTURE.md       # System architecture
    ├── MODULES.md            # Module reference
    ├── TESTING.md            # Testing guide
    └── DEBUG_PROTOCOL.md     # Debug specification
```

## Documentation

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System design overview and component diagrams
- **[MODULES.md](docs/MODULES.md)** - Detailed module documentation and signal references
- **[TESTING.md](docs/TESTING.md)** - Simulation execution and test methodology
- **[DEBUG_PROTOCOL.md](docs/DEBUG_PROTOCOL.md)** - RISC-V debugging protocol reference

## Key Specifications

| Aspect | Specification |
|--------|---------------|
| **ISA** | RV32I (RISC-V 32-bit Base Integer) |
| **Pipeline** | 5-stage |
| **Registers** | 32 × 32-bit GPRs |
| **Debug Interface** | JTAG (IEEE 1149.1) + DMI |
| **Debug Spec** | RISC-V Debug v0.13.2 |
| **Simulation** | Verilator |
| **HDL** | SystemVerilog |

## Development

### Running a Simple Test

```bash
# Build and run DTM test with coverage
make coverage suite=dtm tb=tb_dtm_top

# View the generated waveform (if available)
gtkwave dump.vcd
```

### Understanding Coverage

Coverage reports show which lines of code were executed during testing:
- **Covered**: Executed at least once
- **Uncovered**: Never executed during simulation

Improve coverage by writing more comprehensive tests in `tb/` directories.

## Debugging with GDB/OpenOCD (Future)

Once integration is complete, you can connect external debuggers:
```bash
openocd -f interface/ftdi/digilent-hs1.cfg -f target/riscv.cfg
gdb program.elf
(gdb) target remote localhost:3333
```

## Contributing

When contributing code:
1. Follow SystemVerilog naming conventions (find detailed guide in [MODULES.md](docs/MODULES.md))
2. Ensure all tests pass: `make coverage suite=<suite>`
3. Maintain or improve code coverage
4. Update documentation for new features

## Performance Targets

- **Clock Frequency**: 100+ MHz
- **Area**: 4–5K LUTs (estimated)
- **Power**: ~200 mW (estimated)
- **CPI**: ~1.3–1.5 (cycles per instruction)

## Current Status

- ✅ TAP FSM (JTAG controller state machine)
- ✅ JTAG IR/DR registers
- ✅ DMI protocol
- ✅ Basic Debug Module
- 🔄 Full specification compliance (Phase 2)
- 🔄 Abstract commands (Phase 2)
- 📋 Programme buffer support (Phase 2/3)

## Limitations

- **Multiply/Divide**: Not yet implemented (RV32M extension)
- **CSRs**: Limited to essential debug/control CSRs
- **Exception Handling**: Basic only
- **Memory**: Simplified, single-cycle access

## License


## Contact & Support

For questions or issues:
- Open an issue on the repository
- Check existing documentation in `/docs`
- Review test cases in `/tb` for usage examples

---

**Last Updated**: April 2026  
**Maintainer**: Sonia Kim  
**Status**: Active Development – Phase 2
