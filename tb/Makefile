VERILATOR ?= verilator
TB        ?= tb_fault_inject

RTL_CORE = \
	../rtl/package/riscv_pkg.sv \
	../rtl/package/dmi_pkg.sv \
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

.PHONY: core run clean

core:
	$(VERILATOR) --binary --sv --timing --trace $(RTL_CORE) core/$(TB).sv --top-module $(TB) -o sim_$(TB)
	./obj_dir/sim_$(TB)

clean:
	rm -rf obj_dir *.vcd coverage.dat coverage.txt
