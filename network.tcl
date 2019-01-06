
set ::clients {}
array set ::network {
	callback {}
}

array set ::networkBuffers {

}

proc n_initialize {callback} {
	set ::network(callback) $callback
	n_listenForClients $::config(tcpServicePort)
}

proc n_pushData {data} {
	foreach channel $::clients {
		puts $channel $data
	}
}

proc n_listenForClients {port} {
	socket -server n_onClientConnected $port
}

proc n_onClientConnected {channel addr port} {
	fconfigure $channel -translation binary -encoding binary -buffering none -blocking 0
	fileevent $channel readable [list n_onClientData $channel]

	lappend ::clients $channel
	set ::networkBuffers($channel) {}
	eval $::network(callback) connected
	debug NETWORK "Client connected from $addr:$port"
}

proc n_onClientData {channel} {
	try {
		set data [read $channel]
	} on error {err info} {
		set data {}
	}
	if {[string bytelength $data] == 0} {
		n_onClientDisconnected $channel
	} else {
		append ::networkBuffers($channel) $data
		set parts [split $::networkBuffers($channel) \n]
		if {[llength $parts] > 1} {
			set queue [lrange $parts 0 end-1]
			set ::networkBuffers($channel) [lindex $parts end]
			foreach part $queue {
					eval $::network(callback) data $part
			}
		}
	}
}

proc n_onClientDisconnected {channel} {
	catch {
		close $channel
	}
	set ::clients [lsearch -all -inline -exact -not $::clients $channel]
	catch {
			unset ::networkBuffers($channel)
	}
	if {$::clients eq {}} {
		eval $::network(callback) disconnected
	}
	debug NETWORK "Client disconnected"
}
