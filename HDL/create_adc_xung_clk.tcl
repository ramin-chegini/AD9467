# Run with the destination Vivado project open:
# source /path/to/create_adc_xung_clk.tcl
if {[llength [get_projects -quiet]] == 0} {
    error "Open the destination project before sourcing this script."
}
if {[llength [get_ips -quiet adc_xung_clk]] == 0} {
    create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name adc_xung_clk
}
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.PRIM_SOURCE {No_buffer} \
    CONFIG.PRIMARY_PORT {clk_in1} \
    CONFIG.NUM_OUT_CLKS {4} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {20.000} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.CLKOUT4_USED {true} \
    CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {333.33333} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
    CONFIG.USE_LOCKED {true} \
] [get_ips adc_xung_clk]
generate_target all [get_ips adc_xung_clk]
