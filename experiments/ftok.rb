#!/usr/bin/ruby
#
# Learning about SysVIPC's ftok().
# 
# Time-stamp: <05-Sep-2003 12:11:04 deveiant>
#

BEGIN {
	base = File::dirname( File::dirname(File::expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
	require 'sysvipc'
}

if ARGV.empty?
	errorMessage "Usage: #{File::basename($0)} <pathname>"
	exit( 1 )
end

pathname = ARGV.shift
stat = File::stat( pathname )
proj_id = 0x45

key = SystemVIPC::ftok( pathname, proj_id )

puts "st_dev: %1x, st_ino: %1x, key: %x" %
	[ stat.dev, stat.ino, key ]




