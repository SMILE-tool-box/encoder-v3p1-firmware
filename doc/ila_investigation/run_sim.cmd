@echo off
setlocal
set "VIVADO_BIN=C:\Xilinx\Vivado\2024.2\bin"
cd /d "%~dp0"
if not exist .work\sim mkdir .work\sim
cd .work\sim
call "%VIVADO_BIN%\xvhdl.bat" --2008 ../../../../Vivado_project/Encoder_v3.1_Firmware.srcs/sources_1/new/RBCP_REG.vhd ../../../../Vivado_project/Encoder_v3.1_Firmware.srcs/sources_1/imports/GigaIwaki/DAC_set.vhd ../../tb_rbcp_dac.vhd
if errorlevel 1 exit /b 1
call "%VIVADO_BIN%\xelab.bat" tb_rbcp_dac -s tb_rbcp_dac_sim -debug typical
if errorlevel 1 exit /b 1
call "%VIVADO_BIN%\xsim.bat" tb_rbcp_dac_sim -runall
exit /b %errorlevel%
