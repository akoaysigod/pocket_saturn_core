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
set_min_delay -from $hold_a_from -to $hold_a_to 0.600
set_min_delay -from $hold_b_from -to $hold_b_to 0.600
