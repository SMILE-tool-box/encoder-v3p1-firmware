# Usage: vivado -mode batch -source scripts/build_clean.tcl -tclargs <new-output-dir>
# A fresh project prevents reuse of historical synthesis/place/route checkpoints.
set root [file normalize [file join [file dirname [info script]] ..]]
if {$argc < 1 || $argc > 2} {error "Specify output directory and optional internal|external clock mode"}
set ::env(ENCODER_CLOCK_MODE) internal
if {$argc == 2} {set ::env(ENCODER_CLOCK_MODE) [lindex $argv 1]}
if {$::env(ENCODER_CLOCK_MODE) ni {internal external}} {error "Invalid clock mode"}
set out [file normalize [lindex $argv 0]]
if {[file exists $out]} {error "Output already exists; use a new directory: $out"}
file mkdir $out
set_param general.maxThreads 4
create_project ab [file join $out project] -part xc7s100fgga676-2
set_property target_language VHDL [current_project]
set sources [file join $root Vivado_project Encoder_v3.1_Firmware.srcs sources_1]
foreach dir {new imports/GigaIwaki imports/Desktop} {
    foreach f [glob -nocomplain [file join $sources $dir *.vhd] [file join $sources $dir *.v] [file join $sources $dir *.edf]] {
        add_files -norecurse $f
    }
}
set_property file_type {VHDL 2008} [get_files *.vhd]
foreach f [glob [file join $sources ip *.xcix]] {import_ip -files $f}
set constraints [file join $root Vivado_project Encoder_v3.1_Firmware.srcs constrs_1 imports Desktop]
add_files -fileset constrs_1 [file join $constraints FE2009bal_u_Gigabit_RO_V3.xdc]
add_files -fileset constrs_1 [file join $constraints EDF_SiTCP.xdc]
set_property top main [current_fileset]
update_compile_order -fileset sources_1
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
set_property generate_synth_checkpoint true [get_files -all *.xci]
generate_target all [get_ips]
foreach ip [get_ips] {create_ip_run $ip}
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_cdc -details -file [file join $out cdc.rpt]
report_clock_interaction -file [file join $out clock_interaction.rpt]
report_methodology -file [file join $out methodology.rpt]
report_utilization -file [file join $out utilization.rpt]
write_checkpoint [file join $out routed.dcp]
set f [open [file join $out design_info.txt] w]
puts $f "Vivado: [version -short]"
puts $f "Root: $root"
puts $f "Clock mode: $::env(ENCODER_CLOCK_MODE)"
puts $f "Debug cores: [get_debug_cores -quiet]"
puts $f "Incremental synthesis/implementation: disabled"
close $f
foreach delay {max min} {
    set paths [get_timing_paths -delay_type $delay -max_paths 1]
    if {[llength $paths] == 0} {error "No $delay timing paths"}
    if {[get_property SLACK $paths] < 0} {error "$delay timing fails; bitstream not generated"}
}
write_bitstream -bin_file [file join $out main.bit]
exit
