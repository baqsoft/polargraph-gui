
array set ::config {
	screenWidth 320
	screenHeight 240
	devMode 0
	version 1.1
	tcpServicePort 20002
}

proc debug {args} {
	if {[llength $args] == 2} {
		lassign $args prefix msg
	} else {
		set prefix DEBUG
		set msg $args
	}
	set time [clock format [clock seconds] -format "%H:%M:%S"]
	puts "\[$prefix\] $time: $msg"
}

dict for {key value} [array get ::config] {
	debug CONFIG "$key = $value"
}
