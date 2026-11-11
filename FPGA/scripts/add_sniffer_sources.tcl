# Add migrated sniffer / TinyFPGA / enum sources to senior_design.xpr and set sim top.
# From FPGA/: vivado -mode batch -source scripts/add_sniffer_sources.tcl -nojournal -nolog

set script_dir [file dirname [file normalize [info script]]]
set proj_dir   [file normalize [file join $script_dir ..]]
set proj_file  [file join $proj_dir senior_design.xpr]
set src        [file join $proj_dir senior_design.srcs sources_1 new]
set sim        [file join $proj_dir senior_design.srcs sim_1 new]
set constr     [file join $proj_dir senior_design.srcs constrs_1 new]

open_project $proj_file

foreach f [list \
  [file join $src strobe.v] \
  [file join $src usb_fs_rx.v] \
  [file join $src usb_reset_det.v] \
  [file join $src usb_packet_frontend.sv] \
  [file join $src isolation_controller.sv] \
  [file join $src enumeration_analysis.sv] \
  [file join $src sniffer_block.sv] \
  [file join $src sniffer_wrapper.sv] \
  [file join $src register_file.sv] \
  [file join $src spi_slave.sv] \
  [file join $src clk_wiz_12_to_48.sv] \
  [file join $src usb_fs_tx.v] \
  [file join $src usb_demo_selfstim.sv] \
  [file join $src main_wrapper.sv] \
] {
  if {[llength [get_files -quiet $f]] == 0} {
    add_files -norecurse $f
    puts "Added design: $f"
  }
}

foreach f [list \
  [file join $constr cmod_s7_bringup.xdc] \
] {
  if {[llength [get_files -quiet $f]] == 0} {
    add_files -fileset constrs_1 -norecurse $f
    puts "Added constr: $f"
  }
}

foreach f [list \
  [file join $sim tb_sniffer.sv] \
  [file join $sim tb_enumeration_analysis.sv] \
  [file join $sim tb_kill_e2e.sv] \
  [file join $sim tb_enum_e2e.sv] \
  [file join $sim tb_demo_threat.sv] \
  [file join $sim tb_spi_enum_e2e.sv] \
  [file join $sim tb_main_selfstim.sv] \
  [file join $sim tb_spi_manual_kill.sv] \
  [file join $sim tb_kill_manual_cross.sv] \
  [file join $sim tb_cov_isolation.sv] \
  [file join $sim tb_cov_sniffer.sv] \
  [file join $sim isolation_controller_sva.sv] \
  [file join $sim sniffer_block_sva.sv] \
  [file join $sim enumeration_analysis_sva.sv] \
  [file join $sim usb_packet_frontend_sva.sv] \
  [file join $sim sniffer_wrapper_sva.sv] \
  [file join $sim register_file_sva.sv] \
  [file join $sim spi_slave_sva.sv] \
  [file join $sim main_wrapper_sva.sv] \
] {
  if {[llength [get_files -quiet -of_objects [get_filesets sim_1] $f]] == 0} {
    add_files -fileset sim_1 -norecurse $f
    puts "Added sim: $f"
  }
}

# usb_fs_tx lives in sources_1 (selfstim + sim stimulus). Drop stale sim-only copy.
set tx_sim [get_files -quiet -of_objects [get_filesets sim_1] */usb_fs_tx.v]
if {[llength $tx_sim]} {
  remove_files -fileset sim_1 $tx_sim
  puts "Removed stale sim usb_fs_tx"
}

set_property top main_wrapper [get_filesets sources_1]
set_property top tb_sniffer [get_filesets sim_1]
set_property include_dirs [list $src] [get_filesets sources_1]
set_property include_dirs [list $src] [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "sources top=[get_property top [get_filesets sources_1]]"
puts "sim top=[get_property top [get_filesets sim_1]]"

# Vivado 2018.2: close_project persists .xpr (save_project_as fails if already open)
close_project
puts "add_sniffer_sources.tcl done."
exit 0
