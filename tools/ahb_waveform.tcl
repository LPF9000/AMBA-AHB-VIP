# Load the AHB interface signals without depending on the testbench top name.
set selected [list]
for {set i 0} {$i < [gtkwave::getNumFacs]} {incr i} {
    set name [gtkwave::getFacName $i]
    if {[regexp {\.bus\.(HCLK|HRESETn|HSEL|HREADY|HREADYOUT|HRESP|HTRANS|HADDR|HSIZE|HBURST|HWRITE|HWDATA|HRDATA)(\[.*\])?$} $name]} {
        lappend selected $name
    }
}
set added [gtkwave::addSignalsFromList $selected]
puts "AHB_VIEWER_SIGNALS=$added"
gtkwave::/Time/Zoom/Zoom_Full

if {[info exists ::env(AHB_WAVE_SESSION)]} {
    set session [open $::env(AHB_WAVE_SESSION) w]
    puts $session "\[dumpfile\] \"[file normalize [gtkwave::getDumpFileName]]\""
    puts $session {@28}
    foreach name $selected {
        puts $session $name
    }
    close $session
}

if {[info exists ::env(AHB_VIEWER_CHECK)]} {
    if {$added == 0} {
        puts "AHB_VIEWER_FAIL: no AHB interface signals loaded"
    } else {
        puts "AHB_VIEWER_PASS: [gtkwave::getDumpFileName]"
    }
    gtkwave::/File/Quit
}
