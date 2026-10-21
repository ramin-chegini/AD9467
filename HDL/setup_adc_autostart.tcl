# Run in the real project BEFORE synthesis. Updates the existing VIO IP.
if {[llength [get_projects -quiet]] == 0} {error "Open the destination project first."}
set adc_dir [file dirname [file normalize [info script]]]
foreach name {adc_training_pkg.vhd adc_idelay_loader.vhd adc_pn9_trainer.vhd ad9467_startup.vhd} {
    set src [file join $adc_dir $name]
    if {[llength [get_files -quiet $src]] == 0} {add_files -norecurse $src}
}
source [file join $adc_dir create_adc_align_vio.tcl]
update_compile_order -fileset sources_1
puts "ADC PN9 autostart sources and debug IP ready. Rebuild bitstream and .ltx."
