# Run in the Tcl Console of the open destination project.
if {[llength [get_projects -quiet]] == 0} {
    error "Open the destination Vivado project first."
}
set script_dir [file dirname [file normalize [info script]]]
set ip_name vio_adc_align
if {[llength [get_ips -quiet $ip_name]] == 0} {
    create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name $ip_name
}
set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {4} \
    CONFIG.C_PROBE_IN0_WIDTH {16} CONFIG.C_PROBE_IN1_WIDTH {16} \
    CONFIG.C_PROBE_IN2_WIDTH {16} CONFIG.C_PROBE_IN3_WIDTH {16} \
    CONFIG.C_NUM_PROBE_OUT {5} \
    CONFIG.C_PROBE_OUT0_WIDTH {3} CONFIG.C_PROBE_OUT0_INIT_VAL {0x4} \
    CONFIG.C_PROBE_OUT1_WIDTH {3} CONFIG.C_PROBE_OUT1_INIT_VAL {0x1} \
    CONFIG.C_PROBE_OUT2_WIDTH {3} CONFIG.C_PROBE_OUT2_INIT_VAL {0x1} \
    CONFIG.C_PROBE_OUT3_WIDTH {3} CONFIG.C_PROBE_OUT3_INIT_VAL {0x1} \
    CONFIG.C_PROBE_OUT4_WIDTH {1} CONFIG.C_PROBE_OUT4_INIT_VAL {0x0} \
] [get_ips $ip_name]
generate_target all [get_ips $ip_name]
set cdc_file [file join $script_dir adc_align_cdc.xdc]
if {[llength [get_files -quiet $cdc_file]] == 0} {
    add_files -fileset constrs_1 -norecurse $cdc_file
}
update_compile_order -fileset sources_1
puts "vio_adc_align ready: outputs 0..3 = channel modes 1..6; output 4 = APPLY toggle."
puts "Inputs 0..3: bit15 trained, bit14 channel fail, bit13 RUN, bit12 startup fail, bits11:9 mode, bits8:0 tap."
puts "Build bitstream and use its matching .ltx in Hardware Manager."
