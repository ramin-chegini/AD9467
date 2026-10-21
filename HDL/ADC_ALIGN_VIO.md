# PN9 Calibration and VIO Reference

This document applies to the `ADC_orihard` top-level module. Training starts automatically after reset; manual VIO interaction is optional.

## Training flow

Each receiver first scans six word-reconstruction modes at delays `0, 8, …, 504`. After settling, it must acquire 32 consecutive correct PN9 words within 128 cycles, then verify another 1024 correct words. The first mismatch rejects the candidate.

The midpoint of the longest passing window is selected. A window must contain at least four passing points; equal-width windows retain the first result. This stage uses a common delay target for all eight lanes of one ADC.

If no common window is found, `adc_lane_pn9_trainer` tries reconstruction modes with independent lane delays. A reliable lane provides the PN reference, and the other lanes are checked against the predicted sequence. A final full-word check verifies agreement across all 16 bits.

After restoring EN_VTC and allowing settling, 4096 correct words are required for final acceptance. Stuck inputs and the forbidden PN state are rejected. The startup sequencer also has an independent watchdog: the default training timeout is 500 ms.

## Current channel mapping

| Physical ADC | Receiver | VIO status input | Raw output |
|---|---|---|---|
| ADC1 | `u_ad1` | `probe_in0` | `ADC1_DATA` / `ADC1_CLK` |
| ADC2 | `u_ad2` | `probe_in1` | `ADC2_DATA` / `ADC2_CLK` |
| ADC3 | `u_ad3` | `probe_in2` | `ADC3_DATA` / `ADC3_CLK` |
| ADC4 | `u_ad4` | `probe_in3` | `ADC4_DATA` / `ADC4_CLK` |

This module has no FIFO or LED outputs. Parent-design routing through `xn` or board LEDs is outside the current interface.

## VIO status inputs

Each `probe_in` is a 16-bit status word:

| Bits | Meaning |
|---|---|
| 15 | This channel passed startup training |
| 14 | This channel failed training |
| 13 | All-channel startup and the return to normal mode have completed |
| 12 | The startup sequencer entered a fault state |
| 11:9 | Active reconstruction mode, 1 through 6 |
| 8:0 | Reported delay target |

The multi-bit status bus is diagnostic and is not an atomic snapshot while scanning. Read it after status settles. During common-delay training, the reported target applies to all lanes. During independent deskew, it reports the currently selected internal lane target, rather than all eight targets. Observe the internal `delay_lane_targets` signal to inspect every lane value.

The reported tap is a selected target and may differ from the instantaneous count after voltage and temperature compensation. `deskew_active` and `deskew_lane_fail` are internal signals without dedicated fields in the current four VIO status words.

## Manual reconstruction-mode control

| VIO output | Signal | Initial value |
|---|---|---|
| `probe_out0` | `align_mode_ch1` | 4 |
| `probe_out1` | `align_mode_ch2` | 1 |
| `probe_out2` | `align_mode_ch3` | 1 |
| `probe_out3` | `align_mode_ch4` | 1 |
| `probe_out4` | `align_apply` | 0 |

The VIO defaults do not automatically overwrite the learned modes. Manual changes are accepted only after normal acquisition begins.

For lane `i`, each pair below maps to `data(2*i+1), data(2*i)`. Q1 and Q2 are the DDR outputs; `n-1` denotes the previous DCO cycle.

| Mode | Bit pair |
|---|---|
| 1 | `Q1[n], Q2[n]` |
| 2 | `Q2[n], Q1[n]` |
| 3 | `Q1[n], Q2[n-1]` |
| 4 | `Q2[n-1], Q1[n]` |
| 5 | `Q1[n-1], Q2[n]` |
| 6 | `Q2[n], Q1[n-1]` |

Use unsigned decimal radix in Hardware Manager. Commit the desired modes first and keep them stable, then toggle `align_apply` in a separate transaction. Both `0→1` and `1→0` apply a change; a pulse is unnecessary. Mode codes 0 and 7 retain the previous mode.

Allow at least eight running local DCO cycles after applying a change, and discard transition samples. Each channel applies the change in its own domain, so simultaneous application across channels is not guaranteed.

A manual change updates reconstruction order only. It does not change the delay or rerun PN9. Bit 15 continues to report that startup training passed; it does not verify the new manual mode. Reset restarts automatic training.

## IP and constraint integration

The saved project is `Prj/AD9467_ADC_Driver.xpr`. When reusing the HDL scripts in another design, check the active sources, IP versions and constraint paths. `setup_adc_autostart.tcl` adds the four training sources, and `create_adc_align_vio.tcl` configures the VIO probes.

The current project uses `Constraints/adc_align_cdc.xdc`. The earlier VIO script refers to the file with the same name under `HDL/`. These constraint files belong to different integrations. Check that their destination-register patterns match the actual design hierarchy after integration changes.

Use the `.ltx` file generated for the same bitstream in Hardware Manager. A passing PN9 sequence does not replace setup/hold analysis and board-specific ADC input timing constraints.

Test-pattern reference: [AD9467 datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/AD9467.pdf).
