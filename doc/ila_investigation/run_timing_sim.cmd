@echo off
setlocal
set "VIVADO_BIN=C:\Xilinx\Vivado\2024.2\bin"
cd /d "%~dp0"
if not exist .work\timing_sim mkdir .work\timing_sim
cd .work\timing_sim
call "%VIVADO_BIN%\xvhdl.bat" --2008 ../../../../Vivado_project/Encoder_v3.1_Firmware.srcs/sources_1/imports/GigaIwaki/DAC_set.vhd ../../tb_serial_timing.vhd
if errorlevel 1 exit /b 1
call "%VIVADO_BIN%\xelab.bat" tb_serial_timing -s tb_serial_timing_sim
if errorlevel 1 exit /b 1
call "%VIVADO_BIN%\xsim.bat" tb_serial_timing_sim -runall
exit /b %errorlevel%
