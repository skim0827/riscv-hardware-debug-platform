VERILATOR = verilator
FILELIST  = filelist.f

tb ?= tb_alu

core:
	$(VERILATOR) --sv --trace --binary -f $(FILELIST) tb/core/$(tb).sv --top-module $(tb)

debug:
	$(VERILATOR) --sv --trace --binary -f $(FILELIST) tb/debug/$(tb).sv --top-module $(tb)

dtm:
	$(VERILATOR) --sv --trace --binary -f $(FILELIST) tb/dtm/$(tb).sv --top-module $(tb)

jtag:
	$(VERILATOR) --sv --trace --binary -f $(FILELIST) tb/jtag/$(tb).sv --top-module $(tb)

system:
	$(VERILATOR) --sv --trace --binary -f $(FILELIST) tb/system/$(tb).sv --top-module $(tb)

run:
	./obj_dir/V$(tb)

clean:
	rm -rf obj_dir *.vcd