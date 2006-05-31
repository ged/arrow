#!/usr/bin/ruby
#
# I can't remember if you can specify a default for a block
# 
# Time-stamp: <22-Apr-2006 13:29:19 ged>
#

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
}

def something_with_a_block
	yield
end

try( "block_default_arg" ) {
	something_with_a_block {|foo=nil| p foo }
}


