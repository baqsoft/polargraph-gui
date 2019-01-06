#!/usr/bin/tclsh
package require Tk
set ::cwd [file dirname [file dirname [file normalize [info script]/_]]]
foreach dep {
	config
	gui
	network
	serial
	filesystem
	polargraph
	geometry
} {
	source [file join $::cwd ${dep}.tcl]
}

proc serialCallback {command args} {
	switch -- $command {
		data {
			debug SERIAL $args
			n_pushData $args
			p_handleData $args
			switch -glob -- $args {
				READY {
					set ::guiData(hasPg) 1
				}
				"LS1 *" {
					set ::guiData(limit1) [expr {[lindex $args end] eq 0}]
				}
				"LS2 *" {
					set ::guiData(limit2) [expr {[lindex $args end] eq 0}]
				}
			}
		}
	}
}

proc networkCallback {command args} {
	switch -- $command {
		disconnected {
			set ::guiData(hasClients) 0
		}
		connected {
			set ::guiData(hasClients) 1
		}
		data {
			debug NETWORK $args
			s_pushData [lindex $args 0]
		}
	}
}

proc filesystemCallback {command args} {
	switch -- $command {
		plugged {
			set ::guiData(usbDrive) 1
			p_onUsbDrivePlugged $args
			set programFile [file join $args program.nc]
			set ::guiData(programFile) [file exists $programFile]
		}
		unplugged {
			set ::guiData(usbDrive) 0
			set ::guiData(programFile) 0
		}
	}
}

proc polargraphCallback {command args} {
	switch -- $command {
		config {
			foreach key {velocity accel thrust} {
				set ::guiData($key) [dict get $args $key]
			}
		}
		program {
			set ::guiData(programBuffer) $args
		}
		progress {
			set ::guiData(programProgress) $args
		}
		started {
			set ::guiData(started) $args
		}
		processing {
			set ::guiData(processing) $args
		}
		data {
			debug "Pushing command: $args"
			s_pushData $args
			if {$::config(devMode)} {
				set ::dataAfterId [after 100 {
					serialCallback data READY
				}]
			}
		}
	}
}

proc guiCallback {command args} {
	switch -- $command {
		transition {
			switch -glob -- [join $args ->] {
				settings->* {
					set newConfig [dict create]
					foreach key {velocity accel thrust} {
						dict set newConfig $key $::guiData($key)
					}
					if {[p_reconfigure $newConfig]} {
						p_saveConfig
					}
				}
			}
		}
		loadProgram {
			p_loadProgram
		}
		process {
			p_startProcessing
		}
		stop {
			p_toggleProcessing
		}
		polargraph {
			p_do [lindex $args 0] {*}[lrange $args 1 end]
		}
	}
}

try {
	g_initialize guiCallback
	n_initialize networkCallback
	s_initialize serialCallback
	p_initialize polargraphCallback
	f_initialize filesystemCallback

	if {$::config(devMode)} {
		after 1000 	serialCallback data READY
	}
} on error {err info} {
	debug ERROR "error during initialization: [dict get $info -errorinfo]"
}

# source C:/Users/baq/Desktop/Polargraph/polargraph-gui/polargraph-gui.tcl
