@echo off
setlocal
set "VIVADO_BIN=C:\Xilinx\Vivado\2024.2\bin"
cd /d "%~dp0"
if not exist .work\reset_sim mkdir .work\reset_sim
cd .work\reset_sim
call "%VIVADO_BIN%\xvhdl.bat" --2008 ../../../../Vivado_project/Encoder_v3.1_Firmware.srcs/sources_1/new/reset_release.vhd ../../tb_reset_release.vhd
if errorlevel 1 exit /b 1
call "%VIVADO_BIN%\xelab.bat" tb_reset_release -s tb_reset_sim
if errorlevel 1 exit /b 1
call "%VIVADO_BIN%\xsim.bat" tb_reset_sim -runall
exit /b %errorlevel%
