

array set ::geometry {
	r {}
	width {}
	pi 3.1415926535897931
}

proc geo_setParameters {circ width} {
	set ::geometry(r) [expr {$circ / $::geometry(pi) / 2}]
	set ::geometry(width) $width
	debug "GEOMETRY" "r = $::geometry(r)"
	debug "GEOMETRY" "width = $::geometry(width)"
}

proc geo_calculateLength {x y} {
	upvar 1 ::geometry(r) r
	set l2 [expr {$x*$x + $y*$y}]
	set d [expr {sqrt($l2 - $r*$r)}]
	return [expr {asin(($d*$y + $r*$x) / $l2)*$r + $d}]
}

proc geo_getLengths {x y} {
	return [list [geo_calculateLength $x $y] [geo_calculateLength [expr {$::geometry(width) - $x}] $y]]
}
