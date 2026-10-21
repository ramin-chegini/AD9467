# Integration and Bring-Up Guide

This guide describes the control and receive paths of `ADC_orihard`. The [project README](../README.md) provides the architecture overview and engineering highlights.

## Open the project

Open `Prj/AD9467_ADC_Driver.xpr` in Vivado. The saved project records Vivado 2025.2 and targets `xcvu9p-flga2104-2-i`. The top-level module is `ADC_orihard`.

The six active VHDL sources are:

```text
adc_training_pkg.vhd
adc_idelay_loader.vhd
adc_pn9_trainer.vhd
M_AD9516_Ctrl.vhd
ad9467_startup.vhd
ADC_orihard.vhd
```

The required `adc_xung_clk` and `vio_adc_align` IP containers are under `IP/`. Other HDL files are supporting blocks or earlier design versions; see the [source guide](../HDL/README.md).

## Board integration

`sys_clk` requires a buffered 100 MHz input. `rst_n` is active low. Each ADC provides eight differential data lanes, a differential DCO and its own SPI connections. The AD9516 has a separate SPI control path, and `CpSl_AD9516_LD_i` supplies its lock status to the startup logic.

Pin assignments, I/O standards and ADC input timing constraints depend on the board. `Constraints/adc_align_cdc.xdc` contains CDC constraints, including some hierarchy names inherited from the parent design. Verify those matches against the actual integration. The clock-generator register profile must also match the exact AD9516 variant and the board reference clock.

## Behavior after reset

1. The supervisor controls MMCM reset from the incoming clock domain.
2. After clock lock, the input-delay primitives leave reset in the required order.
3. The AD9516 controller sends its configuration table. Its own startup does not depend on AD9516 lock already being asserted.
4. After AD9516 lock and IDELAY readiness, the ADC sequencer completes its wait interval and enables PN9.
5. Each receiver searches reconstruction modes and input delays using its own DCO.
6. If common-delay training fails, the receiver tries independent lane deskew.
7. Once all receivers pass, the ADCs leave test mode. `ADC_READY` asserts after the flush interval.

The control clock is 20 MHz. `clk_25m` and `S6_25MCLK` are legacy names; interpret the startup timing parameters using the actual 20 MHz clock.

## Status signals

| Signal | Meaning |
|---|---|
| `CLOCK_LOCKED = 1` | MMCM lock status has been synchronized into the incoming clock domain |
| `IDELAY_READY = 1` | Delay-controller readiness has been synchronized into the incoming clock domain |
| `ADC_READY = 1` | All four receivers passed training and the return to normal mode has completed |
| `ADC_TRAIN_FAILED = 1` | The startup sequencer has entered a fault state |

`ADC_READY` does not establish deterministic sample alignment between ADCs or validate board-level physical constraints. The consumer must handle readiness and data transfers into its own clock domain. This interface has no output FIFO.

See the [VIO reference](../HDL/ADC_ALIGN_VIO.md) for per-channel reconstruction modes, reported delays and manual controls.

## Suggested technical walkthrough

1. **Clock configuration:** explain the AD9516 register table, SPI frame construction and IO_UPDATE writes in `M_AD9516_Ctrl.vhd`.
2. **ADC configuration:** show the `CONFIG` and `NORMAL` command arrays in `ad9467_startup.vhd`.
3. **Data capture:** follow the differential-input, IDELAY and IDDRE1 path in `ADC_orihard.vhd`.
4. **PN9 checking:** explain next-word prediction and comparison in `adc_training_pkg.vhd` and the trainer.
5. **Delay selection:** describe eye-center selection and the independent-lane fallback.
6. **Readiness:** show why normal acquisition starts only after all four receivers succeed.

A short project introduction:

> This project implements FPGA-based bring-up of four AD9467 ADCs and an AD9516 clock generator. SPI controllers program the devices, while PN9 checking calibrates DDR word reconstruction and input delays. The interface reports readiness only after all four receivers pass training and the ADCs return to normal acquisition.

Support hardware performance claims with actual board photographs, VIO/ILA captures and measurement reports that state the operating conditions. The current repository makes no claim about measured SNR, ENOB or sampling rate.
