# Run in an empty Vivado batch process, from a disposable working directory.
set adc_dir [file normalize [file join [file dirname [info script]] ..]]
create_project -in_memory -part xcku060-ffva1156-2-i
source [file join $adc_dir setup_adc_autostart.tcl]
source [file join $adc_dir create_adc_xung_clk.tcl]
# Include actual IP RTL in this standalone synthesis instead of black boxes.
foreach ip {vio_adc_align adc_xung_clk} {
    set_property generate_synth_checkpoint false [get_files [get_property IP_FILE [get_ips $ip]]]
}
read_vhdl [file join $adc_dir M_AD9516_Ctrl.vhd]
read_vhdl [file join $adc_dir ADC_xung.vhd]
synth_design -mode out_of_context -top ADC_xung -part xcku060-ffva1156-2-i
if {[llength $adc_align_meta] != 24} {error "Expected 24 receiver CDC first-stage bits"}
if {[llength $adc_startup_meta] != 9} {error "Expected 9 startup CDC first-stage bits"}
if {[llength $adc_receiver_reset] != 12} {error "Expected 12 receiver reset synchronizer bits"}
if {[llength $adc_startup_reset] != 3} {error "Expected 3 startup reset synchronizer bits"}
if {[llength $adc_status_meta] < 48} {error "ADC diagnostic CDC constraints did not match"}
if {[llength [get_cells -hier -filter {REF_NAME == IDELAYE3}]] != 32} {error "Expected 32 IDELAYE3"}
create_clock -period 10.000 [get_ports sys_clk]
foreach ch {1 2 3 4} {create_clock -period 4.882 [get_ports AD${ch}_DCO_P]}
report_utilization -file adc_utilization.rpt
report_timing_summary -file adc_synth_timing.rpt
write_checkpoint -force adc_autostart_synth.dcp
puts "ADC_AUTOSTART_SYNTHESIS_PASSED"
