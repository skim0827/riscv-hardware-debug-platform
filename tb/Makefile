VERILATOR ?= verilator
tb        ?= $(if $(TB),$(TB),tb_fault_inject)

VERILATOR_FLAGS ?= --binary --sv --timing --trace -Wno-TIMESCALEMOD +define+SIMULATION

TB_DIRS = . core bus peripheral debug dtm system
TB_FILE = $(firstword $(foreach dir,$(TB_DIRS),$(wildcard $(dir)/$(tb).sv)))
AVAILABLE_TBS = $(sort $(basename $(notdir $(wildcard tb_*.sv */tb_*.sv))))

RTL_PKGS = \
	../rtl/package/riscv_pkg.sv \
	../rtl/package/dmi_pkg.sv \
	../rtl/package/axi4_lite_pkg.sv

RTL_CORE = \
	../rtl/core/program_counter.sv \
	../rtl/core/regfile.sv \
	../rtl/core/main_fsm.sv \
	../rtl/core/tmr_pc.sv \
	../rtl/core/tmr_regfile.sv \
	../rtl/core/tmr_main_fsm.sv \
	../rtl/core/alu.sv \
	../rtl/core/alu_decoder.sv \
	../rtl/core/instr_decoder.sv \
	../rtl/core/signext.sv \
	../rtl/core/memory.sv \
	../rtl/core/control.sv \
	../rtl/core/cpu_top.sv

RTL_DEBUG = \
	../rtl/package/dmi_pkg.sv \
	../rtl/package/riscv_pkg.sv \
	../rtl/debug/progbuf.sv \
	../rtl/debug/dmi_cdc_bridge.sv \
	../rtl/debug/debug_module.sv

RTL_DTM = \
	../rtl/package/dmi_pkg.sv \
	../rtl/dtm/dtm_top.sv

RTL_SYSTEM = \
	$(RTL_PKGS) \
	$(RTL_CORE) \
	../rtl/debug/progbuf.sv \
	../rtl/debug/dmi_cdc_bridge.sv \
	../rtl/debug/debug_module.sv \
	../rtl/jtag/tap_fsm.sv \
	../rtl/dtm/dtm_top.sv \
	../rtl/peripheral/health_monitor.sv \
	../rtl/system/system_top.sv

RTL_AXI_MEM = \
	../rtl/package/axi4_lite_pkg.sv \
	../rtl/core/memory.sv \
	../rtl/peripheral/axi4_lite_mem_slave.sv

RTL_AXI_UART = \
	../rtl/package/axi4_lite_pkg.sv \
	../rtl/peripheral/uart_tx.sv \
	../rtl/peripheral/axi4_lite_uart_slave.sv

RTL_AXI_TIMER = \
	../rtl/package/axi4_lite_pkg.sv \
	../rtl/peripheral/timer_wdt.sv \
	../rtl/peripheral/axi4_lite_timer_slave.sv

RTL_AXI_HEALTH = \
	../rtl/package/axi4_lite_pkg.sv \
	../rtl/peripheral/health_monitor.sv \
	../rtl/peripheral/axi4_lite_health_slave.sv

# Full SoC for system-level testbenches.
# Uses memory_ecc.sv (pure-SV arrays) instead of memory.sv (Vivado BRAM IP).
RTL_SOC_FULL = \
	$(RTL_PKGS) \
	../rtl/core/alu.sv \
	../rtl/core/alu_decoder.sv \
	../rtl/core/instr_decoder.sv \
	../rtl/core/signext.sv \
	../rtl/core/program_counter.sv \
	../rtl/core/regfile.sv \
	system/bram_sp_39x128.sv \
	system/bram_sp_39x128_dmem.sv \
	../rtl/core/memory.sv \
	../rtl/core/tmr_pc.sv \
	../rtl/core/tmr_regfile.sv \
	../rtl/core/main_fsm.sv \
	../rtl/core/tmr_main_fsm.sv \
	../rtl/core/control.sv \
	../rtl/core/cpu_top.sv \
	../rtl/jtag/tap_fsm.sv \
	../rtl/dtm/dtm_top.sv \
	../rtl/debug/dmi_cdc_bridge.sv \
	../rtl/debug/progbuf.sv \
	../rtl/debug/debug_module.sv \
	../rtl/bus/axi4_lite_crossbar.sv \
	../rtl/bus/axi4_lite_null_slave.sv \
	../rtl/peripheral/axi4_lite_mem_slave.sv \
	../rtl/peripheral/uart_tx.sv \
	../rtl/peripheral/axi4_lite_uart_slave.sv \
	../rtl/peripheral/timer_wdt.sv \
	../rtl/peripheral/axi4_lite_timer_slave.sv \
	../rtl/peripheral/health_monitor.sv \
	../rtl/peripheral/axi4_lite_health_slave.sv \
	../rtl/system/soc_top.sv

TB_SRCS_tb_fault_inject          = \
    ../rtl/package/riscv_pkg.sv \
    ../rtl/package/axi4_lite_pkg.sv \
    $(RTL_CORE) \
    ../rtl/peripheral/axi4_lite_mem_slave.sv \
    system/bram_sp_39x128.sv \
    system/bram_sp_39x128_dmem.sv
TB_SRCS_tb_axi4_lite_mem_slave   = $(RTL_AXI_MEM)
TB_SRCS_tb_axi4_lite_uart_slave  = $(RTL_AXI_UART)
TB_SRCS_tb_axi4_lite_timer_slave = $(RTL_AXI_TIMER)
TB_SRCS_tb_axi4_lite_health_slave = $(RTL_AXI_HEALTH)
TB_SRCS_tb_debug_module          = $(RTL_DEBUG)
TB_SRCS_tb_cdc_cmd_bridge        = ../rtl/debug/dmi_cdc_bridge.sv
TB_SRCS_tb_progbuf               = ../rtl/debug/progbuf.sv
TB_SRCS_tb_dtm_top               = $(RTL_DTM)
TB_SRCS_tb_system_top            = $(RTL_SYSTEM)
TB_SRCS_tb_soc_top               = $(RTL_SYSTEM) ../rtl/system/soc_top.sv
TB_SRCS_tb_hello_fpga            = $(RTL_SOC_FULL)

RTL_SRCS = $(or $(TB_SRCS_$(tb)),$(RTL_CORE))

.DEFAULT_GOAL := run
.PHONY: run core list clean check-tb

run: check-tb
	$(VERILATOR) $(VERILATOR_FLAGS) $(RTL_SRCS) $(TB_FILE) --top-module $(tb) -o sim_$(tb)
	./obj_dir/sim_$(tb)

core: run

list:
	@printf '%s\n' $(AVAILABLE_TBS)

check-tb:
	@test -n "$(TB_FILE)" || { \
		echo "Unknown testbench: $(tb)"; \
		echo "Available testbenches:"; \
		printf '  %s\n' $(AVAILABLE_TBS); \
		exit 1; \
	}

clean:
	rm -rf obj_dir *.vcd coverage.dat coverage.txt
