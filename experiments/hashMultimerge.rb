#!/usr/bin/ruby
#
# Experiment to see if a block argument to Hash#merge would make it possible to
# do multi-level merging.
# 
# Time-stamp: <24-Aug-2003 16:09:37 deveiant>
#

BEGIN {
	base = File::dirname( File::dirname(File::expand_path(__FILE__)) )
	$stderr.puts "Base: #{base}"
	$LOAD_PATH.unshift "#{base}/lib"
	$stderr.puts "Adding '#{base}/lib' to the $LOAD_PATH"

	require "#{base}/utils.rb"
	include UtilityFunctions
}

header "Hash#merge w/block multi-merge experiment"

ohash = {
	:foo => {
		:foo2 => 'origin foo.foo2',
		:bar2 => 'origin foo.bar2',
	},
	:bar => {
		:foo1 => 'origin bar.foo1',
		:bar1 => 'origin bar.bar1',
	},
	:baz => {
		:foo3 => 'origin baz.foo3',
		:bar3 => 'origin baz.bar3',
	},
}

newhash = {
	:foo => {
		:foo2 => 'new foo.foo2',
	},
	:bar => {
		:foo1 => 'new bar.foo1',
	}
}


try( "just a straight ohash#merge( newhash )" ) {
	ohash.merge( newhash )
}

# resolveconflict = nil
resolveconflict = Proc::new {|key, oldval, newval|
	debugMsg "Merging '%s': %s -> %s" %
		[ key.inspect, oldval.inspect, newval.inspect ]
	case oldval
	when Hash
		case newval
		when Hash
			debugMsg "Hash/Hash merge"
			oldval.merge( newval, &resolveconflict )
		else
			newval
		end

	when Array
		case newval
		when Array
			debugMsg "Array/Array union"
			oldval | newval
		else
			newval
		end
	else
		newval
	end
}

try( "ohash#merge( newhash ) { <multi-merge code> }" ) {
	ohash.merge( newhash, &resolveconflict )
}

