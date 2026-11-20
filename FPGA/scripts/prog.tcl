# Program Cmod S7 with the latest impl bitstream.
# Usage (from FPGA/):
#   vivado -mode batch -source scripts/prog.tcl -nojournal -nolog
# Or: make prog
#
# Vivado 2018.2 uses open_hw / close_hw (not open_hw_manager).
# Optional env:
#   BIT=path/to/foo.bit   override bitstream path

set script_dir [file dirname [file normalize [info script]]]
set proj_dir   [file normalize [file join $script_dir ..]]

set bit ""
if {[info exists ::env(BIT)] && $::env(BIT) ne ""} {
  set bit $::env(BIT)
} else {
  set candidates [glob -nocomplain [file join $proj_dir senior_design.runs impl_1 *.bit]]
  if {[llength $candidates] == 0} {
    error "No bitstream under senior_design.runs/impl_1/. Run: make build"
  }
  set bit [lindex [lsort $candidates] 0]
}

if {![file exists $bit]} {
  error "Bitstream not found: $bit"
}
puts "Programming bitstream: $bit"

# Batch mode does not load Hardware Manager until labtools is requested.
catch {load_features labtools}
catch {load_features labtools_2}

# Prefer classic 2018.x API; fall back to newer open_hw_manager if present.
if {[llength [info commands open_hw]] > 0} {
  open_hw
} elseif {[llength [info commands open_hw_manager]] > 0} {
  open_hw_manager
} else {
  error "Neither open_hw nor open_hw_manager is available (try: load_features labtools)."
}

# -allow_non_jtag is newer Vivado only; 2018.2 rejects it.
if {[catch {connect_hw_server -allow_non_jtag} err]} {
  puts "connect_hw_server -allow_non_jtag unavailable ($err); retrying plain connect"
  connect_hw_server
}
open_hw_target

set devices [get_hw_devices]
if {[llength $devices] == 0} {
  error "No hw devices found. Close Hardware Manager in the GUI if it holds the cable, then retry make prog."
}

set dev ""
foreach d $devices {
  set name [get_property NAME $d]
  puts "  found device: $name"
  if {[string match -nocase "*xc7s25*" $name] || [string match -nocase "*7s25*" $name]} {
    set dev $d
  }
}
if {$dev eq ""} {
  set dev [lindex $devices 0]
  puts "WARNING: no xc7s25 match; using first device: [get_property NAME $dev]"
}

current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev
set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
refresh_hw_device $dev

puts "Program complete: [get_property NAME $dev]"

if {[llength [info commands close_hw]] > 0} {
  close_hw
} elseif {[llength [info commands close_hw_manager]] > 0} {
  close_hw_manager
}
exit 0
