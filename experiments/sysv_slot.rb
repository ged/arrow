#!/usr/bin/ruby
#
# Experimenting with SysV IPC message queues
# 
# Time-stamp: <05-Sep-2003 13:08:57 deveiant>
#

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
	require 'sysvipc'
	include SystemVIPC
}

SVMSG_MODE = 0644

try( "Creating 10 message queues" ) {
	10.times do 
		mq = MessageQueue.new( IPC_PRIVATE, SVMSG_MODE|IPC_CREAT )
		puts "Queue: %p" % mq
		mq.remove
	end
}

