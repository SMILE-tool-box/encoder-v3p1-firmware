# Read-only analysis of the saved routed design; does not open or change the project.
set here [file dirname [file normalize [info script]]]
set root [file normalize [file join $here ../..]]
set checkpoint [file join $root Vivado_project Encoder_v3.1_Firmware.runs impl_1 main_routed.dcp]
set label timing
if {$argc > 0} {set checkpoint [file normalize [lindex $argv 0]]}
if {$argc > 1} {set label [lindex $argv 1]}
set out [file join $here .work $label]
file mkdir $out
open_checkpoint $checkpoint
report_timing_summary -report_unconstrained -max_paths 3 -file [file join $out summary.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_clock_interaction -file [file join $out clock_interaction.rpt]
report_cdc -details -file [file join $out cdc.rpt]
report_exceptions -file [file join $out exceptions.rpt]
report_timing -from [get_clocks clk_200M] -to [get_clocks clk_100M] -delay_type min_max -max_paths 10 -file [file join $out 200_to_100.rpt]
report_timing -from [get_clocks clk_100M] -to [get_clocks clk_200M] -delay_type min_max -max_paths 10 -file [file join $out 100_to_200.rpt]
set f [open [file join $out reset_connectivity.txt] w]
foreach pattern {SystemRst* SiTCP_Reset*} {
    foreach n [get_nets -quiet -hier -filter "NAME =~ $pattern"] {
        puts $f "NET $n"
        puts $f "DRIVERS [get_pins -quiet -of_objects $n -filter {DIRECTION == OUT}]"
        puts $f "LOADS [get_pins -quiet -of_objects $n -filter {DIRECTION == IN}]"
    }
}
close $f
report_timing -to [get_ports {CHIP_CK CHIP_WR CHIP_RB CHIP_SD SYNC SDIN SCLK ADC_SYNC ADC_SDIN ADC_SCLK}] -delay_type min_max -max_paths 30 -file [file join $out serial_outputs.rpt]
exit
