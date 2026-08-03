if {$argc != 2} {
    puts "usage: export_xsa.tcl <vivado_xpr> <output_xsa>"
    exit 2
}

set xpr_file [lindex $argv 0]
set xsa_file [lindex $argv 1]

open_project $xpr_file
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
write_hw_platform -fixed -include_bit -force -file $xsa_file
close_project
