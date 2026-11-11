# Sequential XSim regression for sniffer fabric TBs.
# Usage (from FPGA/):
#   vivado -mode batch -source scripts/sim_all.tcl -nojournal -nolog
# Or: make sim-all
# Optional: make sim-all COV=1  (native XSim code coverage when Vivado supports it)
#
# Opens the project once, runs each top with xsim.simulate.runtime=all so
# $display PASS/FAIL lands in simulate.log (read after close_sim), aggregates
# results, exits ≠0 on any failure. Always writes cov/scenario_matrix.txt.

set script_dir [file dirname [file normalize [info script]]]
set proj_dir   [file normalize [file join $script_dir ..]]
set proj_file  [file join $proj_dir senior_design.xpr]
set cov_root   [file join $proj_dir cov]
set cov_db_dir [file join $cov_root xsim_db]
set cov_rpt    [file join $cov_root xsim_report]

source [file join $script_dir cov_enable.tcl]

set tops [list \
  tb_sniffer \
  tb_enumeration_analysis \
  tb_kill_e2e \
  tb_enum_e2e \
  tb_demo_threat \
  tb_spi_enum_e2e \
  tb_main_selfstim \
  tb_spi_manual_kill \
  tb_kill_manual_cross \
  tb_cov_isolation \
  tb_cov_sniffer \
]

if {![file exists $proj_file]} {
  error "Project not found: $proj_file"
}

puts "==== sim_all: opening $proj_file ===="
open_project $proj_file

set failures [list]
set results  [list]
set cov_notes [list]
set native_cc [cov_try_enable $cov_db_dir sim_all_db]
if {$native_cc} {
  lappend cov_notes "native XSim code coverage enabled (sbct)"
} elseif {[info exists ::env(COV)] && $::env(COV) ne "" && $::env(COV) ne "0"} {
  lappend cov_notes "COV=1 requested; native XSim CC unsupported — scenario matrix + procedural isolation checkers"
} else {
  lappend cov_notes "COV unset; scenario matrix only"
}

proc sim_all_check_log {proj_dir top} {
  set log_candidates [list \
    [file join $proj_dir senior_design.sim sim_1 behav xsim simulate.log] \
    [file join $proj_dir senior_design.sim sim_1 behav xsim.log] \
  ]
  set fail 0
  set saw_pass 0
  set pass_pat "${top}: PASS"
  set fail_pat "${top}: FAIL"
  foreach lg $log_candidates {
    if {![file exists $lg]} { continue }
    set fh [open $lg r]
    set txt [read $fh]
    close $fh
    puts "---- $lg (tail) ----"
    set lines [split $txt "\n"]
    set n [llength $lines]
    set start [expr {$n > 40 ? $n - 40 : 0}]
    puts [join [lrange $lines $start end] "\n"]
    if {[regexp $fail_pat $txt]} { set fail 1 }
    if {[regexp $pass_pat $txt]} { set saw_pass 1 }
    if {[regexp {Error:} $txt] && !$saw_pass} { set fail 1 }
    # Procedural SVA failures (*_sva $error "... SVA: ...")
    if {[regexp { SVA:} $txt]} { set fail 1 }
  }
  if {!$saw_pass} {
    puts "ERROR: no '$pass_pat' in simulate.log"
    set fail 1
  }
  return $fail
}

foreach top $tops {
  puts ""
  puts "==== sim_all: $top ===="
  set_property top $top [get_filesets sim_1]
  update_compile_order -fileset sim_1
  puts "Sim top → $top"

  if {[info exists ::env(SIM_TIME)] && $::env(SIM_TIME) ne ""} {
    set_property -name {xsim.simulate.runtime} -value $::env(SIM_TIME) -objects [get_filesets sim_1]
  } else {
    set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
  }

  if {[catch {launch_simulation} err]} {
    puts "ERROR launching $top: $err"
    lappend failures $top
    lappend results "$top FAIL (launch)"
    catch {close_sim}
    continue
  }

  if {$native_cc} {
    cov_try_write $cov_db_dir sim_all_db
  }

  # Flush simulate.log before reading PASS/FAIL.
  catch {close_sim}
  set failed [sim_all_check_log $proj_dir $top]

  if {$failed} {
    puts "==== $top: FAIL ===="
    lappend failures $top
    lappend results "$top FAIL"
  } else {
    puts "==== $top: PASS ===="
    lappend results "$top PASS"
  }
}

puts ""
puts "==== sim_all summary ===="
foreach r $results { puts "  $r" }

file mkdir $cov_root
cov_write_scenario_matrix [file join $cov_root scenario_matrix.txt] $results $cov_notes
if {$native_cc} {
  cov_try_report $cov_db_dir sim_all_db $cov_rpt
}

close_project

if {[llength $failures] > 0} {
  puts "sim_all: FAIL ([llength $failures] broken: [join $failures {, }])"
  error "sim_all reported failures"
}
puts "sim_all: PASS ([llength $tops] tops)"
exit 0
