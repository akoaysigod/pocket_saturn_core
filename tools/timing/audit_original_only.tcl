load_package sta
project_open ap_core
foreach mode {explicit} {
 create_timing_netlist -model slow
 if {$mode eq "automatic"} {read_sdc} else {
  read_sdc -hdl
  read_sdc apf/apf_constraints.sdc
  read_sdc rtl/FX68K/fx68k.sdc
 }
 update_timing_netlist
 file mkdir original_audit/$mode
 check_timing -file original_audit/$mode/health.rpt
 report_clocks -file original_audit/$mode/clocks.rpt
 report_ucp -file original_audit/$mode/unconstrained.rpt
 set i 0
 foreach_in_collection op [get_available_operating_conditions] {
  set_operating_conditions $op
  update_timing_netlist
  foreach kind {setup hold recovery removal mpw} {
   create_timing_summary -$kind -file original_audit/$mode/corner_${i}_${kind}_summary.rpt
  }
  foreach kind {setup hold} {
   report_timing -$kind -npaths 10 -detail full_path -file original_audit/$mode/corner_${i}_${kind}.rpt
  }
  incr i
 }
 delete_timing_netlist
}
project_close
