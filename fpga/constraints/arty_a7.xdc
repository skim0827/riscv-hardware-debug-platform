# 100 MHz system clock
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

# Reset button (BTN0)
set_property PACKAGE_PIN D9 [get_ports rst_btn]
set_property IOSTANDARD LVCMOS33 [get_ports rst_btn]

# UART TX
set_property PACKAGE_PIN D10 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# LEDs
set_property PACKAGE_PIN H5 [get_ports imem_corrected_o]
set_property PACKAGE_PIN J5 [get_ports imem_detected_o]
set_property PACKAGE_PIN T9 [get_ports dmem_corrected_o]
set_property PACKAGE_PIN T10 [get_ports dmem_detected_o]
set_property IOSTANDARD LVCMOS33 [get_ports imem_corrected_o]
set_property IOSTANDARD LVCMOS33 [get_ports imem_detected_o]
set_property IOSTANDARD LVCMOS33 [get_ports dmem_corrected_o]
set_property IOSTANDARD LVCMOS33 [get_ports dmem_detected_o]

# IRQ outputs
set_property PACKAGE_PIN E1 [get_ports timer_irq_o]
set_property PACKAGE_PIN F6 [get_ports health_irq_o]
set_property IOSTANDARD LVCMOS33 [get_ports timer_irq_o]
set_property IOSTANDARD LVCMOS33 [get_ports health_irq_o]

# TMR outputs
set_property PACKAGE_PIN G6 [get_ports tmr_pc_error_o]
set_property PACKAGE_PIN G3 [get_ports tmr_fsm_error_o]
set_property PACKAGE_PIN J3 [get_ports tmr_rf_error_o]
set_property PACKAGE_PIN J2 [get_ports tmr_ir_error_o]
set_property IOSTANDARD LVCMOS33 [get_ports tmr_pc_error_o]
set_property IOSTANDARD LVCMOS33 [get_ports tmr_fsm_error_o]
set_property IOSTANDARD LVCMOS33 [get_ports tmr_rf_error_o]
set_property IOSTANDARD LVCMOS33 [get_ports tmr_ir_error_o]




create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 7 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {imem_araddr[2]} {imem_araddr[3]} {imem_araddr[4]} {imem_araddr[5]} {imem_araddr[6]} {imem_araddr[7]} {imem_araddr[8]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 32 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {ir_20_in[0]} {ir_20_in[1]} {ir_20_in[2]} {ir_20_in[3]} {ir_20_in[4]} {ir_20_in[5]} {ir_20_in[6]} {ir_20_in[7]} {ir_20_in[8]} {ir_20_in[9]} {ir_20_in[10]} {ir_20_in[11]} {ir_20_in[12]} {ir_20_in[13]} {ir_20_in[14]} {ir_20_in[15]} {ir_20_in[16]} {ir_20_in[17]} {ir_20_in[18]} {ir_20_in[19]} {ir_20_in[20]} {ir_20_in[21]} {ir_20_in[22]} {ir_20_in[23]} {ir_20_in[24]} {ir_20_in[25]} {ir_20_in[26]} {ir_20_in[27]} {ir_20_in[28]} {ir_20_in[29]} {ir_20_in[30]} {ir_20_in[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list rst_btn_IBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list ar_addr_r_5]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list u_cpu_n_58]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list imem_arready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list imem_rvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list imem_rready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list rd_state0]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_IBUF_BUFG]
