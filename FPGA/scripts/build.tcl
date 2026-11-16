# Batch synth + impl + bitstream for senior_design.xpr
# Usage: vivado -mode batch -source scripts/build.tcl
# Run from FPGA/ (Makefile does this).

set script_dir [file dirname [file normalize [info script]]]
set proj_dir   [file normalize [file join $script_dir ..]]
set proj_file  [file join $proj_dir senior_design.xpr]

if {![file exists $proj_file]} {
  error "Project not found: $proj_file"
}

puts "Opening $proj_file"
open_project $proj_file

set jobs 4
if {[info exists ::env(VIVADO_JOBS)] && $::env(VIVADO_JOBS) ne ""} {
  set jobs $::env(VIVADO_JOBS)
}

set_property top main_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

# Optional: make build ENABLE_SELFSTIM=0 → live USB taps, no boot dummy HID.
set enable_selfstim 1
if {[info exists ::env(ENABLE_SELFSTIM)] && $::env(ENABLE_SELFSTIM) ne ""} {
  set enable_selfstim $::env(ENABLE_SELFSTIM)
}
puts "ENABLE_SELFSTIM=$enable_selfstim (1=demo selfstim, 0=live taps only)"
if {$enable_selfstim} {
  set_property generic {ENABLE_SELFSTIM=1'b1} [get_filesets sources_1]
} else {
  set_property generic {ENABLE_SELFSTIM=1'b0} [get_filesets sources_1]
}

puts "Synthesis (jobs=$jobs) ..."
reset_run synth_1
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
  error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
}

puts "Implementation + bitstream (jobs=$jobs) ..."
reset_run impl_1
# -to_step write_bitstream forces bitgen even if the GUI run stops earlier.
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "impl_1 STATUS=$impl_status PROGRESS=[get_property PROGRESS [get_runs impl_1]]"
if {![string match -nocase "*write_bitstream*Complete*" $impl_status] &&
    ![string match -nocase "*route_design Complete*" $impl_status] &&
    [get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  error "Implementation failed: $impl_status"
}

set bit [glob -nocomplain [file join $proj_dir senior_design.runs impl_1 *.bit]]
if {[llength $bit] > 0} {
  puts "Bitstream: [lindex $bit 0]"
} else {
  puts "WARNING: no .bit found under senior_design.runs/impl_1/"
}

close_project
puts "Build complete."
exit 0
