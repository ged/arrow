#!/usr/bin/ruby
#
# Experimenting with SysV IPC message queues
# 
# Time-stamp: <05-Sep-2003 14:27:00 deveiant>
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

# /* msgrcv options */
#define MSG_NOERROR     010000  /* no error if message is too big */
#define MSG_EXCEPT      020000  /* recv any msg except of specified type.*/

MSG_NOERROR = 010000
MSG_EXCEPT	= 020000

$oflag		= 0
$usage		= "Usage: #{File.basename( $0 )} [options] <filename> <type> <len>\n"
$id			= 0x45
$truncate	= false

ARGV.options {|oparser|
	oparser.banner = $usage

	oparser.on( "--debug", "-d", TrueClass, "Turn debugging on" ) {
		$DEBUG = true
		debugMsg "Turned debugging on."
	}

	oparser.on( "--truncate", "-t", TrueClass,
		"Truncate messages that are longer than the specified length." ) {
		$truncate = true
		debugMsg "Turned truncation on."
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

filename	= ARGV[0]
type		= ARGV[1].to_i( 10 )
len			= ARGV[2].to_i( 10 )
flags		= 0
flags		|= MSG_NOERROR if $truncate

message "Fetching message queue for #{filename}: \n"
mq = MessageQueue.new( ftok(filename, $id), $oflag )
perm = Permission.new( mq )

message "Opened %p (cuid: %d, cgid: %d, uid: %d, gid: %d, mode: %o)\n" %
	[ mq, perm.cuid, perm.cgid, perm.uid, perm.gid, perm.mode ]

message "Reading message of type %d from queue:\n" % type
msg = mq.recv( type, len, flags )
message "  <#{msg}>\n\n"



