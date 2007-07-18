#!/usr/bin/env ruby
#
# Easy entrypoint into the Arrow::Logger#hierloggers method
# 
# Time-stamp: <24-Aug-2003 16:11:13 deveiant>
#

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"
}

require 'arrow'

p Arrow::Logger[ Arrow::Broker ].hierloggers
