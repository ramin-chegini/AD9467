# Only cut asynchronous inputs to the first synchronizer stage.
# Keep normal timing between synchronizer stages.
# Vivado prefixes registers driven inside a generate with the generate label.
set adc_align_meta [get_cells -quiet -hier -regexp {.*u_ad[1-4]/(clk_NOT_inverted\.|clk_Inverted\.)?(mode_meta_reg\[[0-2]\]|(apply_sync|train_sync|run_sync)_reg\[0\])}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_align_meta -filter {REF_PIN_NAME == D}]
# Startup handshakes are held levels, sampled through two local registers.
set adc_startup_meta [get_cells -quiet -hier -regexp {.*u_startup/(trained_meta_reg\[[0-3]\]|failed_meta_reg\[[0-3]\]|ready_sync_reg\[0\])}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_startup_meta -filter {REF_PIN_NAME == D}]
# VIO status is diagnostic only; read after training settles (not an atomic bus).
set adc_status_meta [get_cells -quiet -hier -regexp {(.*ADC_xung_inst/)?status_meta_reg.*}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_status_meta -filter {REF_PIN_NAME == D}]
set adc_write_meta [get_cells -quiet -hier -regexp {.*Inst_ADCsData_Sync/wr_enable_sync_reg\[0\]}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_write_meta -filter {REF_PIN_NAME == D}]
# Startup-ready asynchronously asserts this reset chain, which releases locally.
set adc_run_reset [get_cells -quiet -hier -regexp {.*adc_ready_local_reg\[[0-2]\]}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_run_reset -filter {REF_PIN_NAME == CLR}]
# Asynchronous assertion into reset-release synchronizers only; retain timing
# from their last stage to the application registers and IDDR reset pins.
set adc_receiver_reset [get_cells -quiet -hier -regexp {.*u_ad[1-4]/reset_(normal|inverted)\.adc_rst_sync_reg\[[0-2]\]}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_receiver_reset -filter {REF_PIN_NAME == PRE}]
set adc_startup_reset [get_cells -quiet -hier -regexp {.*u_startup/reset_sync_reg\[[0-2]\]}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_startup_reset -filter {REF_PIN_NAME == CLR}]
