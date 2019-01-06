
array set ::serial {
	port /dev/ttyAMA0
	callback {}
	mode 57600,n,8,1
	inBuffer {}
	fh {}
}

proc s_initialize {callback} {
	set ::serial(callback) $callback
	if {!$::config(devMode)} {
		s_openSerialPort
	}
}

proc s_pushData {data} {
	if {$::serial(fh) ne {}} {
		puts $::serial(fh) $data
	}
}

proc s_openSerialPort {} {
	set fh [open $::serial(port) RDWR]
	fconfigure $fh -blocking 0 -buffering none -translation binary -encoding binary -mode $::serial(mode)
	fileevent $fh readable [list s_onSerialData $fh]
	set ::serial(fh) $fh
}

proc s_onSerialData {fh} {
	set data [read $fh]
	append ::serial(inBuffer) [string map {\r {}} $data]
	set parts [split $::serial(inBuffer) \n]
	if {[llength $parts] > 1} {
		set queue [lrange $parts 0 end-1]
		set ::serial(inBuffer) [lindex $parts end]
		foreach part $queue {
			s_handleCommand $part
		}
	}
}

proc s_handleCommand {data} {
	eval $::serial(callback) data $data
}
