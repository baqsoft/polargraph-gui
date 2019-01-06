
array set ::polargraph {
	callback {}
	configFile config.tclc
	drive {}
	programBuffer {}
	currentCommand 0
	processing 0
	pendingCommand 0

	firstReady 0
}

array set ::polarconfig {
	velocity 50
	accel 50
	thrust 50
	width 650
	height 650
	mmPerRev 95
	stepsPerRev 400
	segmentLength 2
	homeX 325
	homeY 20
	stepMultiplier 1
	buffering 1
}

proc p_initialize {callback} {
	set ::polargraph(callback) $callback

	# try to load config from file
	set file [file join $::cwd $::polargraph(configFile)]
	if {[file exists $file]} {
		try {
			set fh [open $file r]
			p_reconfigure [read $fh [file size $file]] 1
		} on error {err info} {
			debug POLARGRAPH "could not read config file, overwriting with default"
			p_saveConfig
		} finally {
			catch {
				close $fh
			}
		}
	} else {
		debug POLARGRAPH "config file doesn't exists, creating default"
		p_saveConfig
	}


	p_reset
}

proc p_isInitialized {} {
	return $::polargraph(firstReady)
}

proc p_handleData {data} {
	switch -- $data {
		READY {
			set ::polargraph(firstReady) 1
			if {[p_isInitialized] && $::polargraph(processing)} {
				p_processBuffer
			}
		}
	}
	set ::polargraph(pendingCommand) 0
}

proc p_pushCommand {data} {
	eval $::polargraph(callback) data $data
	set ::polargraph(pendingCommand) 1
}

proc p_reconfigure {newConfig {force 0}} {
	set changed 0
	#set entries 0
	set deltas [dict create]
	foreach key [array names ::polarconfig] {
		if {[dict exists $newConfig $key]} {
				set newValue [dict get $newConfig $key]
				if {$::polarconfig($key) ne $newValue} {
					dict set deltas $key $newValue
						#set ::polarconfig($key) $newValue
						#incr changed
				}
				incr entries
		}
	}
	array set ::polarconfig $deltas
	if {$deltas ne {}} {
			eval $::polargraph(callback) config [array get ::polarconfig]
	}
	debug POLARGRAPH "[dict size $deltas]/$entries config entries reconfigured"
	geo_setParameters $::polarconfig(mmPerRev) $::polarconfig(width)
	## insert configurations into command buffer
	set deltaKeys [expr {$force ? [array names ::polarconfig] : [dict keys $deltas]}]
	if {{width} in $deltaKeys || {height} in $deltaKeys} {
		lappend ::polargraph(programBuffer) "C24,$::polarconfig(width),$::polarconfig(height),END"
	}
	if {{mmPerRev} in $deltaKeys} {
		lappend ::polargraph(programBuffer) "C29,$::polarconfig(mmPerRev),END"
	}
	if {{stepsPerRev} in $deltaKeys} {
		lappend ::polargraph(programBuffer) "C30,$::polarconfig(stepsPerRev),END"
	}
	if {{velocity} in $deltaKeys} {
		lappend ::polargraph(programBuffer) "C31,$::polarconfig(velocity),END"
	}
	if {{accel} in $deltaKeys} {
		lappend ::polargraph(programBuffer) "C32,$::polarconfig(accel),END"
	}
	if {{thrust} in $deltaKeys} {
		lappend ::polargraph(programBuffer) "C82,$::polarconfig(thrust),END"
	}
	if {{homeX} in $deltaKeys || {homeY} in $deltaKeys} {
		set steps [p_mmToSteps {*}[geo_getLengths $::polarconfig(homeX) $::polarconfig(homeY)]]
		lappend ::polargraph(programBuffer) "C09,[lindex $steps 0],[lindex $steps 1],END"
	}
	if {{stepMultiplier} in $deltaKeys} {
		lappend ::polargraph(programBuffer) "C37,$::polarconfig(stepMultiplier),END"
	}
	# start pushing config
	eval $::polargraph(callback) processing [set ::polargraph(processing) 1]
	if {[p_isInitialized] && !$::polargraph(pendingCommand)} {
		p_processBuffer
	}
	# ---
	return [expr {$deltas ne {}}]
}

proc p_onUsbDrivePlugged {drive} {
	set file [file join $drive config.txt]
	if {[file exists $file]} {
		debug POLARGRAPH "attempting to read config from USB drive"
		try {
			set fh [open $file r]
			p_reconfigure [read $fh [file size $file]]
			p_saveConfig
		} on error {err info} {
			debug POLARGRAPH "could not read config from USB drive, aborting.."
		} finally {
			catch {
				close $fh
			}
		}
	}
	set ::polargraph(drive) $drive
}

proc p_saveConfig {} {
	try {
		set file [file join $::cwd $::polargraph(configFile)]
		set fh [open $file w]
		puts -nonewline $fh [array get ::polarconfig]
		debug POLARGRAPH "configuration saved to file"
	} on error {err info} {
		debug POLARGRAPH "could not WRITE config file!"
	} finally {
		catch {
			close $fh
		}
	}
}

proc p_reset {} {
		if (!$::config(devMode)) {
			exec polargraph-reset
		}
}

proc p_loadProgram {} {
	set file [file join $::polargraph(drive) program.nc]
	if {[file exists $file]} {
		set fileSize 0
		set content {}
		try {
			set fileSize [file size $file]
			set fh [open $file r]
			set content [read $fh $fileSize]
		} on error {err info} {
			debug POLARGRAPH "Could not READ program.nc file"
		} finally {
				catch {
					close $fh
				}
		}
		set content [string map {\r {}} $content]
		set intermediateBuffer {}
		foreach record [split $content "\n"] {
			set command [p_createIntermediateCommand $record]
			if {$command ne {}} {
				lappend intermediateBuffer {*}$command
			}
		}
		set ::polargraph(programBuffer) [p_convertBuffer $intermediateBuffer]
		debug POLARGRAPH "Read $fileSize Bytes of program into [llength $::polargraph(programBuffer)] commands"
		eval $::polargraph(callback) program [expr {$::polargraph(programBuffer) ne {}}]
	} else {
		debug POLARGRAPH "PolarGraph program.nc doesn't exists."
	}
}

proc p_createIntermediateCommand {record} {
	set buffer {}
	set xPos {}
	set yPos {}
	foreach entry $record {
		switch -glob -nocase -- $entry {
			G00 {
				lappend buffer "THRUSTOFF"
			}
			G01 {
				lappend buffer "THRUSTON"
			}
			Y* -
			X* {
				set prefix [string index $entry 0]
				set value [string range $entry 1 end]
				set varName [expr {$prefix eq {X} ? {xPos} : {yPos}}]
				set $varName $value
			}
			default {
				debug POLARGRAPH "Could not recognize NC entry '$entry', ignoring.."
			}
		}
	}
	if {$xPos ne {} || $yPos ne {}} {
		#set steps [p_mmToSteps {*}[geo_getLengths $xPos $yPos]]
		lappend buffer [list GO $xPos $yPos]
	}
	return $buffer
}

proc p_convertBuffer {inBuffer} {
	set outBuffer {}

	# intiialize with homing cmd
	set lastX $::polarconfig(homeX)
	set lastY $::polarconfig(homeY)
	lappend outBuffer "C83,END"
	set steps [p_mmToSteps {*}[geo_getLengths $lastX $lastY]]
	lappend outBuffer "C09,[lindex $steps 0],[lindex $steps 1],END"

	#
	set pointsAhead 0
	foreach cmd $inBuffer {
		if {[string match "GO*" $cmd]} {
			incr pointsAhead
		}
	}
	set pointsPassed 0
	foreach cmd $inBuffer {
		switch -glob -- $cmd {
			THRUSTOFF {
				lappend outBuffer "C80,END"
			}
			THRUSTON {
				lappend outBuffer "C81,END"
			}
			GO* {
				incr pointsAhead -1
				if {[lindex $cmd 1] ne {}} {
					set lastX [lindex $cmd 1]
				}
				if {[lindex $cmd 2] ne {}} {
					set lastY [lindex $cmd 2]
				}
				set steps [p_mmToSteps {*}[geo_getLengths $lastX $lastY]]
				if {$::polarconfig(buffering)} {
					# debug TRANSLATE "$lastX,$lastY -> [lindex $steps 0],[lindex $steps 1]"
					lappend outBuffer "C84,[lindex $steps 0],[lindex $steps 1],$pointsPassed,$pointsAhead,END"
				} else {
					lappend outBuffer "C17,[lindex $steps 0],[lindex $steps 1],$::polarconfig(segmentLength),END"
				}
				incr pointsPassed
			}
		}
	}
	return $outBuffer
}

proc p_mmToSteps {args} {
	set stepsList {}
	set stepPerMM [expr {double($::polarconfig(stepsPerRev)) / $::polarconfig(mmPerRev)}]
	foreach arg $args {
		lappend stepsList [expr {int($arg * $stepPerMM)}]
	}
	return $stepsList
}

proc p_startProcessing {} {
	set ::polargraph(currentCommand) 0
	set bufferLength [llength $::polargraph(programBuffer)]
	if {$bufferLength > 0} {
		eval $::polargraph(callback) started 1
		eval $::polargraph(callback) processing [set ::polargraph(processing) 1]
		eval $::polargraph(callback) progress 0
		if {[p_isInitialized]} {
			p_processBuffer
		}
	} else {
		eval $::polargraph(callback) started 0
		eval $::polargraph(callback) processing [set ::polargraph(processing) 0]
		eval $::polargraph(callback) progress 0
	}
}

proc p_processBuffer {} {
	set bufferLength [llength $::polargraph(programBuffer)]
	if {$::polargraph(currentCommand) < $bufferLength} {
		set command [lindex $::polargraph(programBuffer) $::polargraph(currentCommand)]
		p_pushCommand $command
		incr ::polargraph(currentCommand)
		eval $::polargraph(callback) progress [expr {int($::polargraph(currentCommand) * 100 / $bufferLength)}]
	} else {
		eval $::polargraph(callback) started 0
		eval $::polargraph(callback) processing [set ::polargraph(processing) 0]
		eval $::polargraph(callback) progress 0
	}
}

proc p_toggleProcessing {} {
	eval $::polargraph(callback) processing [set ::polargraph(processing) [expr {!$::polargraph(processing)}]]
	if {[p_isInitialized] && !$::polargraph(pendingCommand) && $::polargraph(processing)} {
		p_processBuffer
	}
}

proc p_do {cmd args} {
	switch -- $cmd {
		move {
			# todo
		}
		pen {
			set cmd [expr {$args eq {down} ? {C81} : {C80}}]
			lappend ::polargraph(programBuffer) "$cmd,END"
		}
		home {
			lappend ::polargraph(programBuffer) "C83,END"
			set steps [p_mmToSteps {*}[geo_getLengths $::polarconfig(homeX) $::polarconfig(homeY)]]
			lappend ::polargraph(programBuffer) "C09,[lindex $steps 0],[lindex $steps 1],END"
		}
	}
	eval $::polargraph(callback) processing [set ::polargraph(processing) 1]
	if {[p_isInitialized] && !$::polargraph(pendingCommand)} {
		p_processBuffer
	}
}
