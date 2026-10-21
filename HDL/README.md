# HDL Source Guide

The current top-level module is `ADC_orihard`. Start with the [project README](../README.md) for an overview.

## Active sources

| File | Responsibility |
|---|---|
| `ADC_orihard.vhd` | Connects four ADCs and the AD9516; includes DDR receivers, clock supervision and reset sequencing |
| `M_AD9516_Ctrl.vhd` | Programs the AD9516 clock generator through SPI |
| `ad9467_startup.vhd` | Configures the ADCs, enables PN9 and transitions to normal acquisition |
| `adc_training_pkg.vhd` | PN9 prediction, single-lane state recovery and 16-bit word reconstruction |
| `adc_pn9_trainer.vhd` | Common-delay training with independent lane deskew as a fallback |
| `adc_idelay_loader.vhd` | Bounded input-delay updates and EN_VTC control |
| `tests/` | Existing simulation testbenches and verification scripts |

The project uses [Constraints/adc_align_cdc.xdc](../Constraints/adc_align_cdc.xdc). The file with the same name in this HDL directory belongs to an earlier integration. Do not add both files to the same project. Check constraint hierarchy matches when integrating the interface into a parent design.

## Earlier versions and supporting blocks

The following files are retained as design references and are outside the current active source set:

- `TOP_V2.vhd`: earlier system integration with FIFOs and ILA; requires additional modules and IP.
- `AD_CTR.vhd`: earlier ADC configuration controller.
- `AD_DATA_V2.vhd`: earlier data-receiver implementation.
- `DC_Remover.vhd`: supporting DC-removal block, outside the current raw-data interface.

Use the `sources_1` file set in `Prj/AD9467_ADC_Driver.xpr` to identify the six active VHDL sources. Earlier integration scripts may refer to module names from the previous design.
