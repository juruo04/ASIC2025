# Vivado batch build script for reaction_system_top
# Usage from project root:
#   vivado -mode batch -source build_bitstream.tcl
# Or from Vivado Tcl console:
#   cd D:/FDU/Courses/3B/ASIC/PJ
#   source build_bitstream.tcl

set root_dir [file normalize [file dirname [info script]]]
set project_dir [file join $root_dir Vivado]
set project_name Vivado
set part_name xc7z020clg484-2
set top_name reaction_system_top

set src_files [list \
    [file join $root_dir src reaction_system_top.v] \
    [file join $root_dir src button_debounce_pulse.v] \
    [file join $root_dir src buzzer_driver.v] \
    [file join $root_dir src lfsr_random_service.v] \
    [file join $root_dir src ms_counter_service.v] \
    [file join $root_dir src reaction_controller.v] \
    [file join $root_dir src reaction_core.v] \
    [file join $root_dir src score_history_avg.v] \
    [file join $root_dir src seg7_display_driver.v] \
]

set xdc_file [file join $root_dir xdc reaction_system_gpio1.xdc]
set xpr_file [file join $project_dir ${project_name}.xpr]

puts "== Root       : $root_dir"
puts "== Project    : $xpr_file"
puts "== Top        : $top_name"
puts "== Constraint : $xdc_file"

if {[file exists $xpr_file]} {
    open_project $xpr_file
} else {
    create_project $project_name $project_dir -part $part_name
}

set_property top $top_name [current_fileset]

add_files -norecurse $src_files
add_files -fileset constrs_1 -norecurse $xdc_file
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs 6
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "== synth_1 status: $synth_status"
if {![string match "*Complete*" $synth_status]} {
    error "synth_1 did not complete successfully"
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "== impl_1 status: $impl_status"
if {![string match "*Complete*" $impl_status]} {
    error "impl_1 did not complete successfully"
}

set bit_file [file join $project_dir ${project_name}.runs impl_1 ${top_name}.bit]
puts "== Bitstream: $bit_file"
puts "== Build finished successfully."
