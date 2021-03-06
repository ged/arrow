#!/usr/bin/env ruby -w
#
# Unit test for the Arrow::Session::Lock class
# $Id$
#
# Copyright (c) 2003, 2004 RubyCrafters, LLC. Most rights reserved.
# 
# This work is licensed under the Creative Commons Attribution-ShareAlike
# License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/1.0/ or send a letter to Creative
# Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
#
# 

unless defined? Arrow::TestCase
	testsdir = File.dirname( File.expand_path(__FILE__) )
	basedir = File.dirname( testsdir )
	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/tests/lib" unless
		$LOAD_PATH.include?( "#{basedir}/tests/lib" )

	require 'arrow/testcase'
end

require 'digest/md5'


### Collection of tests for the Arrow::Session::Lock class.
class Arrow::SessionLockTestCase < Arrow::TestCase

	SessionDir			= File.dirname( File.expand_path(__FILE__) ) + "/sessions"

	LockTypes = {
		"file:#{SessionDir}" => 'Arrow::Session::FileLock',
	}

	# If 'posixlock' is installed, test the posix lock type
	begin
		require 'posixlock'
		LockTypes["posix:#{SessionDir}"] = 'Arrow::Session::PosixLock'
	rescue ::Exception => err
	end


	def initialize( *args )
		super

		ctx = Digest::MD5.new
		ctx << Process.pid.to_s
		ctx << Time.now.to_s

		@id = ctx.hexdigest
	end


	#################################################################
	###	T E S T S
	#################################################################

	### Instance test
	def test_00_Instantiate
		assert_block( "Arrow::Session::Lock defined?" ) { defined? Arrow::Session::Lock }
		assert_instance_of Class, Arrow::Session::Lock
	end

	
	### Test the lock component.
	def test_10_LockCreate
		printTestHeader "Session::Lock: Create"
		rval = nil

		LockTypes.each {|uri, type|

			# Should be able to a lock
			assert_nothing_raised do
				rval = Arrow::Session::Lock.create( uri, @id )
			end

			# Lock should support locking/unlocking/predicate methods
			assert_equal type, rval.class.name

			[
				:read_lock, :write_lock, 
				:with_read_lock, :with_write_lock,
				:locked?, :read_locked?, :write_locked?,
				:read_unlock, :write_unlock, :finish
			].each do |meth|
				assert_respond_to rval, meth
			end
		}

		addSetupBlock {
			@locks = LockTypes.keys.collect {|uri|
				Arrow::Session::Lock.create( uri, @id )
			}
		}
		addTeardownBlock {
			unless @locks.nil?
				@locks.each do |lock|
					lock.finish
				end
				@locks = nil
			end
		}
	end


	### Test lock state before any locking
	def test_11_LockBeforeLocking
		printTestHeader "Session::Lock: Before locking"
		rval = nil

		# Locks should start out unlocked
		@locks.each do |lock|
			locktype = lock.class.name

			assert_nothing_raised { rval = lock.locked? }
			assert !rval, "locked? should be false, ie., unlocked (#{locktype})"
			assert_nothing_raised { rval = lock.read_locked? }
			assert !rval, "read_locked? should be false, ie., unlocked (#{locktype})"
			assert_nothing_raised { rval = lock.write_locked? }
			assert !rval, "write_locked? should be false, ie., unlocked (#{locktype})"

			# Lock should raise errors when unlocked without first being locked.
			assert_raises( Arrow::LockingError, locktype ) { lock.read_unlock }
			assert_raises( Arrow::LockingError, locktype ) { lock.write_unlock }
		end
	end


	### Test read lock functionality
	def test_12_LockReadLocking
		printTestHeader "Session::Lock: Read locking"
		rval = nil

		# Read lock should work
		@locks.each do |lock|
			locktype = lock.class.name

			assert_nothing_raised( locktype ) { lock.read_lock }
			assert_nothing_raised( locktype ) { rval = lock.read_locked? }
			assert rval, "read_locked? should be true, ie., read locked (#{locktype})"
			assert_nothing_raised( locktype ) { rval = lock.locked? }
			assert rval, "locked? should be true, ie., either read or write locked (#{locktype})"
			assert_nothing_raised( locktype ) { rval = lock.write_locked? }
			assert !rval, "write_locked? should be false, ie., not write locked (#{locktype})"

			# read_unlock should work and leave it unlocked
			assert_nothing_raised( locktype ) { lock.read_unlock }
			assert_nothing_raised( locktype ) { rval = lock.read_locked? }
			assert !rval, "read_locked? should be false, ie., not locked (#{locktype})"
			assert_nothing_raised( locktype ) { rval = lock.locked? }
			assert !rval, "locked? should be false, ie., not read nor write locked (#{locktype})"
			assert_nothing_raised( locktype ) { rval = lock.write_locked? }
			assert !rval, "write_locked? should be false, ie., not write locked (#{locktype})"
		end
	end


	### Test write lock functionality
	def test_13_LockWriteLocking
		printTestHeader "Session::Lock: Read locking"
		rval = nil

		@locks.each do |lock|
			locktype = lock.class.name

			# Write lock should work
			assert_nothing_raised( locktype ) { lock.write_lock }
			assert_nothing_raised( locktype ) { rval = lock.write_locked? }
			assert rval, "write_locked? should be true, ie., write locked (#{locktype})"
			assert_nothing_raised( locktype ) { rval = lock.locked? }
			assert rval, "locked? should be true, ie., either write or read locked (#{locktype})"
			assert_nothing_raised( locktype ) { rval = lock.read_locked? }
			assert !rval, "read_locked? should be false, ie., not read locked (#{locktype})"

			# write_unlock should work and leave it unlocked
			assert_nothing_raised( locktype ) { lock.write_unlock }
			assert_nothing_raised( locktype ) { rval = lock.write_locked? }
			assert !rval, "write_locked? should be false, ie., not locked (#{locktype})"
			assert_nothing_raised( locktype ) { rval = lock.locked? }
			assert !rval, "locked? should be false, ie., not write nor read locked (#{locktype})"
			assert_nothing_raised( locktype ) { rval = lock.read_locked? }
			assert !rval, "read_locked? should be false, ie., not read locked (#{locktype})"
		end

	end

end

