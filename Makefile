VERILATOR = verilator
FILELIST  = filelist.f

tb ?= tb_alu
suite ?= core

# ============================================================================
# SIMULATION TARGETS
# ============================================================================

core:
	$(VERILATOR) --sv --trace --coverage --binary -f $(FILELIST) tb/core/$(tb).sv --top-module $(tb)

debug:
	$(VERILATOR) --sv --trace --coverage --binary -f $(FILELIST) tb/debug/$(tb).sv --top-module $(tb)

dtm:
	$(VERILATOR) --sv --trace --coverage --binary -f $(FILELIST) tb/dtm/$(tb).sv --top-module $(tb)

jtag:
	$(VERILATOR) --sv --trace --coverage --binary -f $(FILELIST) tb/jtag/$(tb).sv --top-module $(tb)

system:
	$(VERILATOR) --sv --trace --coverage --binary -f $(FILELIST) tb/system/$(tb).sv --top-module $(tb)

run:
	./obj_dir/V$(tb)

# ============================================================================
# COVERAGE TARGETS
# ============================================================================

coverage: $(suite) run coverage_report

coverage_report:
	@echo ""
	@echo "╔════════════════════════════════════════════════════════════════╗"
	@echo "║                  COVERAGE REPORT SUMMARY                       ║"
	@echo "╚════════════════════════════════════════════════════════════════╝"
	@echo ""
	@if [ -f coverage.dat ]; then \
		verilator_coverage --write coverage.txt coverage.dat > /dev/null 2>&1; \
		total=$$(wc -l < coverage.txt); \
		uncovered=$$(grep -c "' 0$$" coverage.txt); \
		covered=$$((total - uncovered)); \
		if [ $$total -gt 0 ]; then \
			percent=$$((covered * 100 / total)); \
			echo "Total Coverage Points:     $$total"; \
			echo "├─ Covered (1+ exec):      $$covered ($$((100 - percent))%)"; \
			echo "└─ NOT Covered (0 exec):   $$uncovered ($$percent%)"; \
			echo ""; \
			echo "Overall Coverage:          $$((100 - percent))%"; \
			echo ""; \
			echo "📊 Coverage data saved to coverage.txt"; \
		fi; \
	else \
		echo "❌ No coverage.dat found! Run 'make coverage suite=SUITE tb=TESTBENCH' first."; \
	fi
	@echo ""

coverage_view:
	@echo "Top 20 UNCOVERED points (0 executions):"
	@grep "' 0$$" coverage.txt | head -20

clean:
	rm -rf obj_dir *.vcd coverage.dat coverage.txt

# ============================================================================
# USAGE EXAMPLE
# ============================================================================
# make coverage suite=debug tb=tb_debug_module
# make coverage suite=core tb=tb_alu
# make coverage_view                    (view uncovered areas)
# make clean                            (remove all generated files)

# === Synthesis ===
SYNTH_DIR   = synth
RTL_PKGS    = rtl/package/dmi_pkg.sv rtl/package/riscv_pkg.sv
RTL_CORE    = rtl/core/alu.sv rtl/core/alu_decoder.sv rtl/core/instr_decoder.sv \
              rtl/core/signext.sv rtl/core/regfile.sv rtl/core/program_counter.sv \
              rtl/core/memory.sv rtl/core/main_fsm.sv rtl/core/control.sv \
              rtl/core/cpu_top.sv
RTL_DEBUG   = rtl/jtag/tap_fsm.sv rtl/dtm/dtm_top.sv rtl/debug/dmi_cdc_bridge.sv \
              rtl/debug/progbuf.sv rtl/debug/debug_module.sv
RTL_TOP     = rtl/system/system_top.sv
ALL_RTL     = $(RTL_PKGS) $(RTL_CORE) $(RTL_DEBUG) $(RTL_TOP)

.PHONY: synth clean-synth

synth: $(SYNTH_DIR)/system_flat.v
	cd $(SYNTH_DIR) && yosys synth.ys 2>&1 | tee synth_log.txt
	
synth-core: $(SYNTH_DIR)/system_flat.v
	cd $(SYNTH_DIR) && yosys synth_core.ys 2>&1 | tee synth_core_log.txt
$(SYNTH_DIR)/system_flat.v: $(ALL_RTL)
	sv2v $(ALL_RTL) -w $@

clean-synth:
	rm -f $(SYNTH_DIR)/system_flat.v $(SYNTH_DIR)/synth_log.txt $(SYNTH_DIR)/synth_out.v