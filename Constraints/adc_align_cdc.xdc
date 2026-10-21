# Only cut asynchronous inputs to the first synchronizer stage.
# Keep normal timing between synchronizer stages.
# Vivado prefixes registers driven inside a generate with the generate label.
set adc_align_meta [get_cells -quiet -hier -regexp {.*u_ad[1-4]/(clk_NOT_inverted\.|clk_Inverted\.)?(mode_meta_reg\[[0-2]\]|(apply_sync|train_sync|run_sync)_reg\[0\])}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_align_meta -filter {REF_PIN_NAME == D}]
# Startup handshakes are held levels, sampled through two local registers.
set adc_startup_meta [get_cells -quiet -hier -regexp {.*u_startup/(trained_meta_reg\[[0-3]\]|failed_meta_reg\[[0-3]\]|ready_sync_reg\[0\])}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_startup_meta -filter {REF_PIN_NAME == D}]
# VIO status is diagnostic only; read after training settles (not an atomic bus).
set adc_status_meta [get_cells -quiet -hier -regexp {.*FMC[134]_ADC_orihard_inst/status_meta_reg.*}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_status_meta -filter {REF_PIN_NAME == D}]
# MMCM LOCKED and replicated IDELAYCTRL RDY enter the parent 100 MHz domain.
# Only the first stage is asynchronous; keep timing through the second stage.
set adc_clock_meta [get_cells -quiet -hier -regexp {.*u_clock_supervisor/(locked_sync|ready_sync)_reg\[0\]}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_clock_meta -filter {REF_PIN_NAME == D}]
set adc_clock_reset [get_cells -quiet -hier -regexp {.*u_clock_supervisor/reset_release_reg\[[0-2]\]}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_clock_reset -filter {REF_PIN_NAME == CLR}]
# Clock supervisor reset/LOCKED asynchronously assert the local 333 MHz
# release chain. Keep timing from its last stage to the reset sequencer.
set adc_delay_reset [get_cells -quiet -hier -regexp {.*u_delay_reset_sequencer/reset_release_reg\[[0-2]\]}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_delay_reset -filter {REF_PIN_NAME == PRE}]
# ADC FIFO write-enable CDC is now scoped and checked in top_control_upgrade.xdc.
# Startup-ready asynchronously asserts this reset chain, which releases locally.
set adc_run_reset [get_cells -quiet -hier -regexp {.*adc_ready_local_reg\[[0-2]\]}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_run_reset -filter {REF_PIN_NAME == CLR}]
# Asynchronous assertion into reset-release synchronizers only; retain timing
# from their last stage to the application registers and IDDR reset pins.
set adc_receiver_reset [get_cells -quiet -hier -regexp {.*u_ad[1-4]/reset_(normal|inverted)\.adc_rst_sync_reg\[[0-2]\]}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_receiver_reset -filter {REF_PIN_NAME == PRE}]
set adc_startup_reset [get_cells -quiet -hier -regexp {.*u_startup/reset_sync_reg\[[0-2]\]}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_startup_reset -filter {REF_PIN_NAME == CLR}]
# ADC read-side status: cut only the input to the first settling register.
set adc_read_status_meta [get_cells -quiet -hier -regexp {.*u_adc_control_cdc/lock_sync_reg\[0\]}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_read_status_meta -filter {REF_PIN_NAME == D}]
# Assertion is asynchronous; release from the last stage remains timed to all
# DC-remover and FIFO-control registers. Do not cut their recovery paths.
set adc_read_reset_chain [get_cells -quiet -hier -regexp {.*u_adc_control_cdc/(lock_sync_reg\[[0-1]\]|reset_release_reg\[[0-2]\])}]
set_false_path -quiet -to [get_pins -quiet -of_objects $adc_read_reset_chain -filter {REF_PIN_NAME == CLR || REF_PIN_NAME == PRE}]

# BEGIN TwinRx ACK CDC constraints
# Cut only the asynchronous input to stage 0; keep stage 0 -> stage 1 timed.
set twinrx_ack_meta [get_cells -quiet -hier -regexp {(^|.*/)tuner_ack_(user|pscan)_sync_reg\[0\]$}]
set_false_path -quiet -to [get_pins -quiet -of_objects $twinrx_ack_meta -filter {REF_PIN_NAME == D}]
# END TwinRx ACK CDC constraints
