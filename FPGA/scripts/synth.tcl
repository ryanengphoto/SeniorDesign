# Batch synthesis only for senior_design.xpr
# Usage: vivado -mode batch -source scripts/synth.tcl

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

puts "Synthesis (jobs=$jobs) ..."
reset_run synth_1
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
  error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
}

close_project
puts "Synth complete."
exit 0
