# Vivado XSim batch flow for tinyfpga_project (non-project xvlog/xelab/xsim).
# Default top: tb_sniffer_frontend (wrapper + isolation).
# Override: set env SIM_TOP=tb_usb_fs_rx
#
#   vivado -mode batch -source scripts/sim_xsim.tcl -nojournal -nolog

set script_dir [file dirname [file normalize [info script]]]
set root       [file normalize [file join $script_dir ..]]
set rtl        [file join $root rtl]
set sim        [file join $root sim]
set work_dir   [file join $root xsim_work]
set defines_dir [file normalize [file join $root .. senior_design.srcs sources_1 new]]

set sim_top tb_sniffer_frontend
if {[info exists ::env(SIM_TOP)] && $::env(SIM_TOP) ne ""} {
  set sim_top $::env(SIM_TOP)
}

puts "tinyfpga_project XSim root: $root"
puts "SIM_TOP=$sim_top"

file mkdir $work_dir
cd $work_dir

foreach pattern {*.jou *.log *.pb *.wdb xsim.dir} {
  foreach f [glob -nocomplain $pattern] {
    file delete -force $f
  }
}

set rtl_files [list \
  [file join $rtl strobe.v] \
  [file join $rtl usb_fs_rx.v] \
  [file join $rtl usb_fs_tx.v] \
  [file join $rtl usb_packet_frontend.sv] \
  [file join $rtl isolation_controller.sv] \
  [file join $rtl sniffer_channel.sv] \
]

if {$sim_top eq "tb_usb_fs_rx"} {
  set tb_file [file join $sim tb_usb_fs_rx.sv]
} else {
  set tb_file [file join $sim tb_sniffer_frontend.sv]
}

set snap ${sim_top}_sim

puts "xvlog (RTL)..."
set rc [catch {exec xvlog --sv -i $defines_dir {*}$rtl_files} out]
puts $out
if {$rc} { error "xvlog RTL failed" }

puts "xvlog (TB)..."
set rc [catch {exec xvlog --sv -i $defines_dir $tb_file} out]
puts $out
if {$rc} { error "xvlog SV failed" }

puts "xelab..."
set rc [catch {exec xelab -debug typical -s $snap $sim_top} out]
puts $out
if {$rc} { error "xelab failed" }

puts "xsim -R..."
set rc [catch {exec xsim $snap -R} out]
puts $out
if {$rc} { error "xsim failed" }

if {[regexp {tb_[A-Za-z0-9_]+: FAIL} $out]} {
  error "Simulation reported failures"
}
if {[regexp {Error:} $out]} {
  error "Simulation reported errors"
}

puts "tinyfpga_project XSim complete ($sim_top)."
exit 0
