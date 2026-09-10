# Batch behavioral sim (XSim) for senior_design.xpr
# Usage: vivado -mode batch -source scripts/sim.tcl
# Run from FPGA/ (Makefile does this).
#
# Requires a testbench as the sim_1 top (File → Simulation Sources).
# Until then, Vivado will elaborate whatever is set as sim top (currently main_wrapper).

set script_dir [file dirname [file normalize [info script]]]
set proj_dir   [file normalize [file join $script_dir ..]]
set proj_file  [file join $proj_dir senior_design.xpr]

if {![file exists $proj_file]} {
  error "Project not found: $proj_file"
}

puts "Opening $proj_file"
open_project $proj_file

set sim_top [get_property top [get_filesets sim_1]]
puts "Simulation top: $sim_top"

# Optional override: make sim SIM_TOP=tb_foo
if {[info exists ::env(SIM_TOP)] && $::env(SIM_TOP) ne ""} {
  set_property top $::env(SIM_TOP) [get_filesets sim_1]
  update_compile_order -fileset sim_1
  puts "Overrode sim top → $::env(SIM_TOP)"
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
