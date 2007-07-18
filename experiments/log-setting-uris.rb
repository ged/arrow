#!/usr/bin/env ruby
#
# Test URI parts for various styles of logging configuration
# 
# 
#

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
}

PARTS_TO_SHOW = %w{fragment host opaque password path port query registry 
	scheme user hierarchical?}.sort

def show( str )
	begin
		uri = URI.parse( str )
	rescue
		return "*** #{str}: Parse error ***"
	end	
	
	maxwidth = PARTS_TO_SHOW.collect {|s| s.length }.max
	
	puts "-- " + str + " -----"
	for meth in PARTS_TO_SHOW
		puts "%1$*2$s: %3$s" % [ meth, maxwidth, uri.send(meth) ]
	end
	
	puts
end



show "debug"
show "apache:debug"
show "apache://debug"
show "file://debug/tmp/log"
show "file:///tmp/log?debug"
show "dbi:Postgresql:finance:host=localhost;user=www;password=foo"
show "dbi://www:foo@localhost/www.finance?driver=postgresql"


