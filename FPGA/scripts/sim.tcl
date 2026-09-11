# Batch behavioral sim (XSim) for senior_design.xpr
# Usage: vivado -mode batch -source scripts/sim.tcl
# Run from FPGA/ (Makefile does this).
#
# Default sim top is tb_sniffer (dummy smoke test). Override with
#   make sim SIM_TOP=...
# Testbenches must $display TEST PASSED or TEST FAILED. After this
# Tcl finishes, check_sim.py scores sim_last.log / simulate.log
# (Windows-safe, no grep; does not launch Vivado).

set script_dir [file dirname [file normalize [info script]]]
set proj_dir   [file normalize [file join $script_dir ..]]
set proj_file  [file join $proj_dir senior_design.xpr]

if {![file exists $proj_file]} {
  error "Project not found: $proj_file"
}

puts "Opening $proj_file"
open_project $proj_file

set sim_top [get_property top [get_filesets sim_1]]
puts "Simulation top (project): $sim_top"

# make sim SIM_TOP=...  (Makefile defaults to tb_sniffer)
if {[info exists ::env(SIM_TOP)] && $::env(SIM_TOP) ne ""} {
  set_property top $::env(SIM_TOP) [get_filesets sim_1]
  set_property top_auto_set false [get_filesets sim_1]
  update_compile_order -fileset sim_1
  puts "Using sim top → $::env(SIM_TOP)"
}

launch_simulation
# Run until $finish in the TB, or a default time if none.
if {[info exists ::env(SIM_TIME)] && $::env(SIM_TIME) ne ""} {
  run $::env(SIM_TIME)
} else {
  run all
}

close_sim
close_project
puts "Sim complete."
exit 0
