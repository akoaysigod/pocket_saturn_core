load_package sta
project_open ap_core
create_timing_netlist -model slow
read_sdc
update_timing_netlist
file mkdir margin_audit
# Absolute 0.600 ns minimum; preserves normal clock latency treatment.
# Fail closed on logical bitsets, retain every physical duplicate.
proc bound_registers {pattern suffix width label} {
    set logical [get_registers -no_duplicates $pattern]
    set physical [get_registers $pattern]
    set bits {}
    foreach_in_collection node $logical {
        set name [get_register_info -name $node]
        if {![regexp $suffix $name all bit]} {error "Unexpected $label endpoint: $name"}
        lappend bits $bit
    }
    set expected {}
    for {set i 0} {$i < $width} {incr i} {lappend expected $i}
    if {[get_collection_size $logical] != $width || [lsort -integer -unique $bits] ne $expected} {error "Wrong logical bitset: $label"}
    if {[get_collection_size $physical] < $width} {error "Missing physical endpoints: $label"}
    puts "HOLD_BOUND $label logical=$width physical=[get_collection_size $physical]"
    foreach_in_collection node $physical {puts "HOLD_ENDPOINT $label [get_register_info -name $node]"}
    return $physical
}
set hold_a_from [bound_registers {*sdram1*dout[0][*]} {\|sdram1:sdram1\|dout\[0\]\[([0-9]+)\]$} 32 A_from]
set hold_a_to [bound_registers {*VDP2*RA0_BUF[*]} {\|VDP2:VDP2\|RA0_BUF\[([0-9]+)\]$} 32 A_to]
set hold_b_from [bound_registers {*SCSP*MEM_D[*]} {\|SCSP:SCSP\|MEM_D\[([0-9]+)\]$} 16 B_from]
set hold_b_to [bound_registers {*sdram1*din2[*]} {\|sdram1:sdram1\|din2\[([0-9]+)\]$} 16 B_to]
set endpoints [open margin_audit/endpoints.txt w]
foreach {label collection} [list A_from $hold_a_from A_to $hold_a_to B_from $hold_b_from B_to $hold_b_to] {
 foreach_in_collection node $collection {puts $endpoints "$label [get_register_info -name $node]"}
}
close $endpoints
set i 0
foreach_in_collection op [get_available_operating_conditions] {
 set_operating_conditions $op
 update_timing_netlist
 foreach {family from to} [list A $hold_a_from $hold_a_to B $hold_b_from $hold_b_to] {
  report_timing -hold -from $from -to $to -npaths [get_collection_size $to] -nworst 1 -detail full_path -file margin_audit/corner_${i}_${family}_hold.rpt
 }
 incr i
}
if {$i != 4} {error "Expected four operating conditions"}
delete_timing_netlist
project_close
