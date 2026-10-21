@echo off
setlocal
rem Run from a Vivado command prompt (settings64.bat).
if not defined XILINX_VIVADO (
  echo Run settings64.bat from your Vivado installation first.
  exit /b 1
)
set "ADC_SRC=%~dp0.."
set "ADC_TEST_OUT=%~dp0..\..\..\tmp\adc_autostart_sim"
if not exist "%ADC_TEST_OUT%" mkdir "%ADC_TEST_OUT%"
pushd "%ADC_TEST_OUT%"
call "%XILINX_VIVADO%\bin\xvhdl.bat" --2008 "%ADC_SRC%\adc_training_pkg.vhd" "%ADC_SRC%\adc_idelay_loader.vhd" "%ADC_SRC%\adc_pn9_trainer.vhd" "%ADC_SRC%\ad9467_startup.vhd" "%ADC_SRC%\M_AD9516_Ctrl.vhd" "%ADC_SRC%\ADC_orihard.vhd" "%~dp0tb_adc_training.vhd" "%~dp0tb_adc_lane_training.vhd" "%~dp0tb_ad9467_startup.vhd" "%~dp0tb_adc_clock_supervisor.vhd" "%~dp0tb_adc_delay_reset.vhd"
if errorlevel 1 goto fail
for %%T in (tb_adc_training tb_adc_lane_training tb_ad9467_startup tb_adc_clock_supervisor tb_adc_delay_reset) do (
  call "%XILINX_VIVADO%\bin\xelab.bat" work.%%T -s %%T
  if errorlevel 1 goto fail
  call "%XILINX_VIVADO%\bin\xsim.bat" %%T -runall -onerror quit -onfinish quit -log %%T.log
  if errorlevel 1 goto fail
  findstr /c:"PASS:" %%T.log >nul
  if errorlevel 1 goto fail
)
echo ADC_AUTOSTART_TESTS_PASSED
popd
exit /b 0
:fail
popd
exit /b 1
