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