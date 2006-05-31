#!/usr/bin/ruby
#
# Experimenting with SysV IPC message queues
# 
# Time-stamp: <06-Sep-2003 06:26:50 deveiant>
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

$oflag	= 0
$usage	= "Usage: #{File.basename( $0 )} [options] <filename> <type> <msg>\n"
$id		= 0x45

ARGV.options {|oparser|
	oparser.banner = $usage

	oparser.on( "--debug", "-d", TrueClass, "Turn debugging on" ) {
		$DEBUG = true
		debugMsg "Turned debugging on."
	}

	# Handle the 'help' option
	oparser.on( "--help", "-h", "Display this text." ) {
		$stderr.puts oparser
		exit!(0)
	}

	oparser.parse!
}

if ARGV.length != 3
	errorMessage $usage
	exit( 1 )
end

filename = ARGV[0]
type = ARGV[1].to_i( 10 )
msg = ARGV[2]

message "Fetching message queue for #{filename}: \n"
mq = MessageQueue.new( ftok(filename, $id), $oflag )
perm = Permission.new( mq )

message "Opened %p (cuid: %d, cgid: %d, uid: %d, gid: %d, mode: %o)\n" %
	[ mq, perm.cuid, perm.cgid, perm.uid, perm.gid, perm.mode ]

message "Writing message '%s' of type %d to queue..." %
	[ msg, type ]
mq.send( type, msg )
message "sent.\n\n"



