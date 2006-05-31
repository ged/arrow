#!/usr/bin/ruby
#
# Trying to find a graceful way to find the file a Class is defined in.
# 
# Time-stamp: <01-Oct-2003 11:57:38 deveiant>
#

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
}

begin
	require 'arrow'
rescue Exception => err
	message "Warning: One or more classes failed to load: #{err.message}"
end

$yaml = false

def findfile( klass )
	begin
		klass.instance_eval { raise }
	rescue StandardError => err
		debugMsg "backtrace is: #{err.backtrace.join(%Q{\n})}"
		sawieval = false
		guess = err.backtrace.each {|frame|
			if /instance_eval/ =~ frame
				sawieval = true
			elsif sawieval
				break frame.sub( /^([^:]+):.*/, "\\1" )
			end
		}
	end
end

try( "findfile( Arrow::Broker )", binding )

