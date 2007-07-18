#!/usr/bin/env ruby
#
# Loader script for testing various means of loading apps
# 
# Time-stamp: <24-Aug-2003 16:11:42 deveiant>
#

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
}

$yaml = false

def load_class( sourcecode, filename )
	classes = sourcecode.scan( /^class (\w+)/ )
	sourcecode << "\n\n#{classes[0]}\n\n"
	eval( sourcecode, nil, filename, 1 )
end


rval = nil
filename = "experiments/loadme.rb"
try( "loader" ) {
	source = File.read( filename )
	rval = load_class( source, filename )
}

try( "to instantiate the returned class" ) {
	obj = rval.new( 5 )
}


