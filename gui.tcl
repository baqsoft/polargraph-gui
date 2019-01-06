
array set ::gui {
	callback {}
}

array set ::guiData {
	hasClients 0
	hasPg 0
	pen 0
	penLatch 0
	limit1 0
	limit2 0
	velocity 50
	accel 50
	thrust 50
	usbDrive 0
	programFile 0
	programBuffer 0
	programProgress 0
	processing 0
	started 0
	timer 3

}

array set ::nav {
	current {}
}

array set ::text {
	appName "PolarGraph UI"
	control "Sterowanie"
	settings "Ustawienia"
	processing "Wykonanie projektu"
	reboot "Reboot"
	poweroff "Wylacz"
	back "Powrot"
	up "\u21E7"
	left "\u21E6"
	on "\u26AB"
	off "\u26AA"
	right "\u21E8"
	down "\u21E9"
	homing "Baza"
	limit1 "KR1"
	limit2 "KR2"
	notConnected "Nie polaczony"
	connected "Polaczony"
	polargraph "PG:"
	client "Klient:"
	velocity "Predkosc:"
	accel "Przysp.:"
	thrust "Sila docisku:"
	usbDrive "Pamiec przenosna"
	loadProgram "Wczytaj program"
	process "Wykonaj"
	stop "Stop"
	resume "Wznow"
}

# components

proc indicator {path args} {
	array set options $args
	foreach key [array names options] {
		if {$key ni {
			-text
			-variable
			-fg
		}} {
			return -code error "unknown switch $key"
		}
	}

	set frame [frame $path]
	grid columnconfigure $frame 1 -weight 1

	upvar 1 $options(-variable) valueVar
	set indicatorFormatter {apply {{value} {
		return [expr {$value ? $::text(on) : $::text(off)}]
	}}}
	set indicator [label $frame.indicator -text [eval $indicatorFormatter $valueVar] -fg $options(-fg) -font "TkIconFont 16"]
	grid $indicator -row 0 -column 0
	trace add variable valueVar write [list apply {{indicator indicatorFormatter varName indexName op} {
		set value [subst $${varName}($indexName)]
		$indicator configure -text [eval $indicatorFormatter $value]
	}} $indicator $indicatorFormatter]
	set label [label $frame.label -text $options(-text)]
	grid $label -row 0 -column 1 -sticky w

	return $path
}

proc g_getExprMapping {expr} {
	set mapping [dict create]
	foreach token $expr {
		if {$token ni {&& ||}} {
			if {[string index $token 0] eq {!}} {
				set token [string range $token 1 end]
			}
			dict set mapping $token [set $token]
		}
	}
	return $mapping
}

proc controlledButton {path args} {
	set stateVarSwitchIndex [lsearch -exact $args -stateVariable]
	set stateExpr {}
	if {$stateVarSwitchIndex != -1} {
		set stateExpr [lindex $args [expr {$stateVarSwitchIndex + 1}]]
		set args [lreplace $args $stateVarSwitchIndex [incr stateVarSwitchIndex]]
	}


	set button [button $path {*}$args]
	if {$stateExpr ne {}} {
		set stateSupplier {apply {{expr} {
			set expr [string map [g_getExprMapping $expr] $expr]
			set value [expr $expr]
			return [expr {$value ? {normal} : {disabled}}]
		}}}

		foreach varName [dict keys [g_getExprMapping $stateExpr]] {
			trace add variable $varName write [list apply {{button stateSupplier varName indexName op} {
				$button configure -state [eval $stateSupplier]
			}} $button [list {*}$stateSupplier $stateExpr]]
		}
		$button configure -state [eval $stateSupplier [list $stateExpr]]
	}
	return $button
}


# gui

proc g_initialize {callback} {
	set ::gui(callback) $callback

	# configure window
	wm geometry . $::config(screenWidth)x$::config(screenHeight)

	# initialize
	grid [g_createUI .main] -row 0 -column 0 -sticky nswe
	grid columnconfigure . 0 -weight 1
	grid rowconfigure . 0 -weight 1
}

proc g_createUI {path} {
	set mainFrame [frame $path -padx 5 -pady 5]

	foreach {id creator} {
		main g_createMainMenu
		control g_createControlMenu
		settings g_createSettingsMenu
		processing g_createProcessingMenu
		timer g_createTimerPopup
	} {
		set ::nav($id) [$creator $mainFrame.$id]
	}

	grid $::nav(main) -row 0 -column 0 -sticky nswe
	grid columnconfigure $mainFrame 0 -weight 1
	grid rowconfigure $mainFrame 0 -weight 1
	return $mainFrame
}

proc g_createTimerPopup {path} {
	set frame [frame $path -bg black]
	grid rowconfigure $frame 0 -weight 1
	grid columnconfigure $frame 0 -weight 1

	set timerLabel [label $frame.label -textvariable ::guiData(timer) -font "-size 26" -fg white -bg black]
	grid $timerLabel -row 0 -column 0 -sticky nswe

	return $frame
}

proc g_createNavFrame {path subFramePathVar} {
	upvar 1 $subFramePathVar subFrame

	set frame [frame $path]
	grid columnconfigure $frame 0 -weight 1
	grid rowconfigure $frame 0 -weight 1

	set subFrame [frame $path.frame]
	grid $subFrame -row 0 -column 0 -sticky nswe

	set backButton [button $frame.back -text $::text(back) -height 2 -command a_mainNav]
	grid $backButton -row 1 -column 0 -sticky es

	return $frame
}

proc g_createHeader {path} {
	set frame [frame $path]
	set title [label $frame.label -text $::text(appName) -font "-size 14"]
	grid $title -row 0 -column 0 -rowspan 2 -sticky w
	grid columnconfigure $frame 0 -weight 1

	# statuses
	set statusSetter {apply {{label varName indexName op} {
		set value [subst $${varName}($indexName)]
		$label configure -text [expr {$value ? $::text(connected) : $::text(notConnected)}] -fg [expr {$value ? "green" : "red"}]
	}}}
	set pgStatusTitle [label $path.pgStatusTitle -text $::text(polargraph)]
	grid $pgStatusTitle -row 0 -column 1 -sticky w
	set pgStatusLabel [label $path.pgStatusLabel -text $::text(notConnected) -fg "red"]
	trace add variable ::guiData(hasPg) write [list {*}$statusSetter $pgStatusLabel]
	grid $pgStatusLabel -row 0 -column 2 -sticky w
	set clientStatusTitle [label $path.clientStatusTitle -text $::text(client)]
	grid $clientStatusTitle -row 1 -column 1 -sticky w
	set clientStatusLabel [label $path.clientStatusLabel -text $::text(notConnected) -fg "red"]
	trace add variable ::guiData(hasClients) write [list {*}$statusSetter $clientStatusLabel]
	grid $clientStatusLabel -row 1 -column 2 -sticky w

	return $frame
}


proc g_createMainMenu {path} {
	set frame [frame $path]
	set header [g_createHeader $frame.header]

	grid $header -row 0 -column 0 -sticky nswe
	grid columnconfigure $frame 0 -weight 1

	set buttonsFrame [frame $frame.buttonsFrame -padx 5 -pady 5]
	grid column $buttonsFrame 0 -weight 1
	grid $buttonsFrame -row 1 -column 0 -sticky nswe
	grid rowconfigure $frame 1 -weight 1

	set controlButton [button $buttonsFrame.control -text $::text(control) -height 2 -command {a_mainNav control}]
	grid $controlButton -row 1 -column 0 -columnspan 2 -sticky we

	set settingsButton [button $buttonsFrame.settings -text $::text(settings) -height 2 -command {a_mainNav settings}]
	grid $settingsButton -row 2 -column 0 -columnspan 2 -sticky we

	set processingButton [button $buttonsFrame.processing -text $::text(processing) -height 2 -command {a_mainNav processing}]
	grid $processingButton -row 3 -column 0 -columnspan 2 -sticky we

	set rebootButton [button $buttonsFrame.reboot -text $::text(reboot) -height 2 -command a_reboot]
	grid $rebootButton -row 4 -column 0 -sticky we

	set poweroffButton [button $buttonsFrame.poweroff -text $::text(poweroff) -height 2]
	bind $poweroffButton <ButtonPress-1> {
		a_startTimer 3 a_poweroff
	}
	bind $poweroffButton <ButtonRelease-1> {
		a_cancelTimer
	}
	grid $poweroffButton -row 4 -column 1 -sticky we

	return $path
}

proc g_createControlMenu {path} {
	set navFrame [g_createNavFrame $path frame]
	grid columnconfigure $frame 0 -weight 1

	set padFrame [frame $frame.padFrame]
	for {set r 0} {$r < 3} {incr r} {
		grid rowconfigure $padFrame $r -weight 1
		grid columnconfigure $padFrame $r -weight 1
	}
	grid $padFrame -row 0 -column 0 -sticky nswe
	grid rowconfigure $frame 0 -weight 1

	#set up [button $padFrame.up -text $::text(up) -command {a_pad up}]
	#grid $up -row 0 -column 1 -sticky nswe
	#set left [button $padFrame.left -text $::text(left) -command {a_pad left}]
	#grid $left -row 1 -column 0 -sticky nswe
	#set right [button $padFrame.right -text $::text(right) -command {a_pad right}]
	#grid $right -row 1 -column 2 -sticky nswe
	#set down [button $padFrame.down -text $::text(down) -command {a_pad down}]
	#grid $down -row 2 -column 1 -sticky nswe

	# config pen
	set iconSupplier {apply {{value} {
		return [expr {$value ? $::text(on) : $::text(off)}]
	}}}
	set pen [button $padFrame.pen -text [eval $iconSupplier $::guiData(pen)]]
	trace add variable ::guiData(pen) write [list apply {{button iconSupplier varName indexName op} {
		set value [subst $${varName}($indexName)]
		$button configure -text [eval $iconSupplier $value]
	}} $pen $iconSupplier]
	grid $pen -row 1 -column 1 -sticky nswe
	bind $pen <ButtonPress-1> {a_pen down}
	bind $pen <ButtonRelease-1> {a_pen up}

	#foreach id {up left pen right down} {
		#$padFrame.$id configure -font "TkIconFont 25"
	#}

	$pen configure -font "TkIconFont 25"

	set homingFrame [frame $frame.homing -pady {5}]
	grid $homingFrame -row 1 -column 0 -sticky nswe
	grid columnconfigure $homingFrame 1 -weight 1
	set homingButton [button $homingFrame.homingButton -text $::text(homing) -height 2 -command a_homing]
	grid $homingButton -row 0 -column 1 -rowspan 2 -sticky nswe

	set limit1 [indicator $homingFrame.limit1 -text $::text(limit1) -variable ::guiData(limit1) -fg green]
	grid $limit1 -row 0 -column 0 -sticky nswe
	set limit2 [indicator $homingFrame.limit2 -text $::text(limit2) -variable ::guiData(limit2) -fg green]
	grid $limit2 -row 1 -column 0 -sticky nswe


	return $navFrame
}

proc g_createSettingsMenu {path} {
	set navFrame [g_createNavFrame $path frame]
	grid columnconfigure $frame 1 -weight 1

	set row 0
	foreach {id from to} {
		velocity 0 1000
		accel 0 1000
		thrust 0 100
	} {
		set label [label $frame.${id}label -text $::text($id)]
		grid $label -row $row -column 0 -sticky w
		set scale [scale $frame.${id}scale -from $from -to $to -orien horizontal -variable ::guiData($id) -width 25]
		grid $scale -row $row -column 1 -sticky we
		grid rowconfigure $frame $row -weight 1
		incr row
	}

	return $navFrame
}

proc g_createProcessingMenu {path} {
	set navFrame [g_createNavFrame $path frame]
	grid columnconfigure $frame 0 -weight 1

	set usbIndicator [indicator $frame.usbDrive -text $::text(usbDrive) -variable ::guiData(usbDrive) -fg blue]
	grid $usbIndicator -row 0 -column 0 -sticky nswe

	set loadButton [controlledButton $frame.loadButton -text $::text(loadProgram) -stateVariable ::guiData(programFile) -command a_loadProgram -height 2]
	grid $loadButton -row 1 -column 0 -sticky nswe

	set programFrame [frame $frame.programFrame]
	#foreach c {0 1} {
	#	grid columnconfigure $programFrame $c -weight 1
	#}
	grid $programFrame -row 2 -column 0 -sticky nswe -pady {5 0}

	set processButton [controlledButton $programFrame.processButton -text $::text(process) -stateVariable {::guiData(programBuffer) && !::guiData(processing)} -command a_process -height 2]
	set stopButtonLabelSupplier {apply {{value} {
		return [expr {$value ? $::text(stop) : $::text(resume)}]
	}}}
	set stopButton [controlledButton $programFrame.stopButton -text [eval $stopButtonLabelSupplier $::guiData(processing)] -stateVariable ::guiData(started) -command a_stop -height 2]
	trace add variable ::guiData(processing) write [list apply {{stopButton labelSupplier varName indexName op} {
		set value [subst $${varName}($indexName)]
		$stopButton configure -text [eval $labelSupplier $value]
	}} $stopButton $stopButtonLabelSupplier]
	pack $processButton $stopButton -fill both -side left -expand 1

	set progress [ttk::progressbar $frame.progress -orient horizontal -mode determinate -variable ::guiData(programProgress)]
	grid $progress -row 3 -column 0 -sticky nswe -pady {2 0}


	return $navFrame
}



# actions

proc a_stop {} {
	debug "Stop button clicked"
	eval $::gui(callback) stop
}

proc a_process {} {
	debug "Process button clicked"
	eval $::gui(callback) process
}

proc a_loadProgram {} {
	debug "LoadProgram button clicked"
	eval $::gui(callback) loadProgram
}

proc a_homing {} {
	debug "Homing button clicked"
	eval $::gui(callback) polargraph home
}

proc a_pad {direction} {
	debug "Control pad clicked: $direction"
	eval $::gui(callback) polargraph move $direction
}

proc a_pen {state} {
	debug "Control pen pressed: $state"
	switch -- $state {
		down {
			set ::guiData(penLatch) 0
			set ::guiData(pen) 1
			eval $::gui(callback) polargraph pen down
			a_startTimer 3 {
				set ::guiData(penLatch) 1
			}
		}
		up {
			if {!$::guiData(penLatch)} {
				set ::guiData(pen) 0
				eval $::gui(callback) polargraph pen up
			}
			a_cancelTimer
		}
	}
}

proc a_mainNav {{targetId main}} {
	debug "Navigation button clicked: $targetId"
	if {$::nav(current) ne {}} {
		set currentId $::nav(current)
		grid remove $::nav($currentId)
	}
	eval $::gui(callback) transition $::nav(current) $targetId
	grid $::nav($targetId) -row 0 -column 0 -sticky nswe
	set ::nav(current) $targetId
}

proc a_startTimer {seconds callback} {
	set tock {apply {{self seconds callback} {
			set ::guiData(timer) $seconds
			if {$seconds == 0} {
				place forget $::nav(timer)
				eval $callback
			} else {
				set ::guiData(timerId) [after 1000 [list {*}$self $self [expr {$seconds - 1}] $callback]]
			}
	}}}
	eval $tock [list $tock $seconds $callback]
	place $::nav(timer) -x 0 -y 0 -height 50 -width 50
}

proc a_cancelTimer {} {
	place forget $::nav(timer)
	if {[info exists ::guiData(timerId)]} {
		after cancel $::guiData(timerId)
	}
}

proc a_reboot {} {
	if {!$::config(devMode)} {
		exec sudo reboot
	}
	debug "Reboot button clicked"
}

proc a_poweroff {} {
	if {!$::config(devMode)} {
		exec sudo poweroff
	}
	debug "Poweroff button clicked"
}
