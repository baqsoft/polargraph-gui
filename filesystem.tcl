

array set ::filesystem {
	callback {}
	drive "/media/usb0"
	testDrive "./testDrive"
	drivemTime -1
	drivePresent 0
}

proc f_initialize {callback} {
	set ::filesystem(callback) $callback
	if {!$::config(devMode)} {
			f_pollUsbDrives
	} else {
		eval $callback plugged $::filesystem(testDrive)
	}
}

proc f_pollUsbDrives {} {
	set drivemTime [file mtime $::filesystem(drive)]
	if {$::filesystem(drivemTime) != $drivemTime} {
		set ::filesystem(drivemTime) $drivemTime
		set drivePresent [f_isUsbDrivePresent]
		debug FILESYSTEM "$::filesystem(drive) change detected $drivemTime, drivePresent = $drivePresent"
		if {$::filesystem(drivePresent) != $drivePresent} {
			set ::filesystem(drivePresent) $drivePresent
			if {$drivePresent} {
				eval $::filesystem(callback) plugged $::filesystem(drive)
			} else {
				eval $::filesystem(callback) unplugged
			}
		}
	}
	after 500 f_pollUsbDrives
}

proc f_isUsbDrivePresent {} {
	set driveIdx [lsearch -exact [exec mount] $::filesystem(drive)]
	return [expr {$driveIdx != -1}]
}
