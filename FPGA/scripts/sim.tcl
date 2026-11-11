# Batch behavioral sim (XSim) for senior_design.xpr
# Usage: vivado -mode batch -source scripts/sim.tcl
# Run from FPGA/ (Makefile does this).
#
# Default sim top is tb_sniffer (sniffer_wrapper port0 CRC/kill bring-up).
# Override: make sim SIM_TOP=...

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
  set sim_top $::env(SIM_TOP)
  set_property top $sim_top [get_filesets sim_1]
  update_compile_order -fileset sim_1
  puts "Overrode sim top → $sim_top"
}

# Put full run into xsim simulate.log (default launch runtime is only 1000ns).
if {[info exists ::env(SIM_TIME)] && $::env(SIM_TIME) ne ""} {
  set_property -name {xsim.simulate.runtime} -value $::env(SIM_TIME) -objects [get_filesets sim_1]
} else {
  set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
}

launch_simulation

# XSim holds/buffers simulate.log until the sim is closed — read after close_sim.
close_sim

set log_candidates [list \
  [file join $proj_dir senior_design.sim sim_1 behav xsim simulate.log] \
  [file join $proj_dir senior_design.sim sim_1 behav xsim.log] \
]
set fail 0
set saw_pass 0
set pass_re {tb_(sniffer|enumeration_analysis|kill_e2e|enum_e2e|demo_threat|spi_enum_e2e|main_selfstim|spi_manual_kill|kill_manual_cross): PASS}
set fail_re {tb_(sniffer|enumeration_analysis|kill_e2e|enum_e2e|demo_threat|spi_enum_e2e|main_selfstim|spi_manual_kill|kill_manual_cross): FAIL}
foreach lg $log_candidates {
  if {[file exists $lg]} {
    set fh [open $lg r]
    set txt [read $fh]
    close $fh
    puts "---- $lg ----"
    puts $txt
    if {[regexp $fail_re $txt]} { set fail 1 }
    if {[regexp $pass_re $txt]} { set saw_pass 1 }
    if {[regexp {Error:} $txt] && !$saw_pass} { set fail 1 }
    if {[regexp {isolation_controller SVA:} $txt]} { set fail 1 }
  }
}
if {!$saw_pass} {
  puts "ERROR: no TB PASS line found in simulate.log for top=$sim_top"
  set fail 1
}

close_project
if {$fail} {
  error "Simulation reported failures"
}
puts "Sim complete."
exit 0
