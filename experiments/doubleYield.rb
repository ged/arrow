#!/usr/bin/env ruby
#
# An experiment to see if you can pass a block to 'yield' to have a kind of
# two-layer handoff in an iterator. This would be useful for making the
# Arrow::Template::Iterator more generic, and thus capable of being used in a
# <?yield?> as well as a <?for?>.
# 
# Time-stamp: <10-Jan-2004 18:45:37 deveiant>
#

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
}

def iterate
	message "Outer #iterate, pre-yield\n"
	yield( lambda {message "Inner #iterate\n"} )
	message "Outer #iterate, post-yield\n"
end


try( "doubleYield" ) {
	iterate {|callback|
		message "Before callback in caller's block\n"
		callback.call
		message "After callback in caller's block\n"
	}
}


