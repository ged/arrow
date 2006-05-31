#!/usr/bin/ruby
#
# Experimenting with SysV IPC message queues
# 
# Time-stamp: <06-Sep-2003 06:49:21 deveiant>
#

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
	require 'sysvipc'
	include SystemVIPC
}

$oflag	= 0644 | IPC_CREAT
$usage	= "Usage: #{File.basename( $0 )} <filename>\n"
$id		= 0x45

if ARGV.empty?
	errorMessage $usage
	exit( 1 )
end
filename = ARGV.shift

message "Removing message queue for #{filename}: "
mq = MessageQueue.new( ftok(filename, $id), $oflag )
message mq.inspect + "\n\n"
mq.remove


