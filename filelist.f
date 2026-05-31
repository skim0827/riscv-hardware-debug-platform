# Packages first — always
rtl/package/riscv_pkg.sv
rtl/package/dmi_pkg.sv
rtl/package/axi4_lite_pkg.sv

# Core
rtl/core/alu.sv
rtl/core/alu_decoder.sv
rtl/core/instr_decoder.sv
rtl/core/signext.sv
rtl/core/program_counter.sv
rtl/core/regfile.sv
rtl/core/memory.sv
rtl/core/tmr_pc.sv
rtl/core/tmr_regfile.sv
rtl/core/main_fsm.sv
rtl/core/tmr_main_fsm.sv
rtl/core/control.sv
rtl/core/cpu_top.sv

# Debug stack
rtl/jtag/tap_fsm.sv
rtl/dtm/dtm_top.sv
rtl/debug/dmi_cdc_bridge.sv
rtl/debug/progbuf.sv
rtl/debug/debug_module.sv

# Bus
rtl/bus/axi4_lite_crossbar.sv
rtl/bus/axi4_lite_null_slave.sv

# Peripherals
rtl/peripheral/axi4_lite_mem_slave.sv
rtl/peripheral/uart_tx.sv
rtl/peripheral/axi4_lite_uart_slave.sv
rtl/peripheral/timer_wdt.sv
rtl/peripheral/axi4_lite_timer_slave.sv
rtl/peripheral/health_monitor.sv
rtl/peripheral/axi4_lite_health_slave.sv

# Top
rtl/system/soc_top.sv