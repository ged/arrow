#!/usr/bin/ruby
#
# Experimenting with SysV IPC message queues
# 
# Time-stamp: <05-Sep-2003 13:26:22 deveiant>
#

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
	require 'sysvipc'
	include SystemVIPC
	require 'optparse'
}

$oflag	= 0644 | IPC_CREAT
$usage	= "Usage: #{File.basename( $0 )} [options] <filename>\n"
$id		= 0x45

ARGV.options {|oparser|
	oparser.banner = $usage

	oparser.on( "--debug", "-d", TrueClass, "Turn debugging on" ) {
		$DEBUG = true
		debugMsg "Turned debugging on."
	}

	oparser.on( "--exclusive", "-e", TrueClass, "Make the queue exclusive" ) {
		$oflag |= IPC_EXCL
		debugMsg "Turned exclusive mode on."
	}

	# Handle the 'help' option
	oparser.on( "--help", "-h", "Display this text." ) {
		$stderr.puts oparser
		exit!(0)
	}

	oparser.parse!
}

if ARGV.empty?
	errorMessage $usage
	exit( 1 )
end
filename = ARGV.shift

message "Creating message queue for #{filename}: "
mq = MessageQueue.new( ftok(filename, $id), $oflag )
message mq.inspect + "\n\n"

