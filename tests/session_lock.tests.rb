#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Session::Lock class
# $Id: 22_session_lock.tests.rb,v 1.1 2003/10/13 04:20:13 deveiant Exp $
#
# Copyright (c) 2003 RubyCrafters, LLC. Most rights reserved.
# 
# This work is licensed under the Creative Commons Attribution-ShareAlike
# License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/1.0/ or send a letter to Creative
# Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
#
# 

unless defined? Arrow::TestCase
	testsdir = File::dirname( File::expand_path(__FILE__) )
	basedir = File::dirname( testsdir )
	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/tests/lib" unless
		$LOAD_PATH.include?( "#{basedir}/tests/lib" )

	require 'arrowtestcase'
end


### Collection of tests for the Arrow::Session::Lock class.
class Arrow::SessionLockTestCase < Arrow::TestCase

	SessionDir			= File::dirname( File::expand_path(__FILE__) ) + "/sessions"
	DefaultLockUri		= "file:#{SessionDir}"
	DefaultLockType		= 'Arrow::Session::FileLock'


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

		# Should be able to a lock
		assert_nothing_raised {
			rval = Arrow::Session::Lock::create( DefaultLockUri, @id )
		}

		# Lock should support locking/unlocking/predicate methods
		assert_equal DefaultLockType, rval.class.name
		[
			:readLock, :writeLock, 
			:withReadLock, :withWriteLock,
			:locked?, :readLocked?, :writeLocked?,
			:readUnlock, :writeUnlock
		].each {|meth|
			assert_respond_to rval, meth
		}

		addSetupBlock {
			@lock = Arrow::Session::Lock::create( DefaultLockUri, @id )
		}
		addTeardownBlock {
			@lock = nil
		}
	end


	### Test lock state before any locking
	def test_11_LockBeforeLocking
		printTestHeader "Session::Lock: Before locking"
		rval = nil

		# Locks should start out unlocked
		assert_nothing_raised { rval = @lock.locked? }
		assert !rval, "locked? should be false, ie., unlocked"
		assert_nothing_raised { rval = @lock.readLocked? }
		assert !rval, "readLocked? should be false, ie., unlocked"
		assert_nothing_raised { rval = @lock.writeLocked? }
		assert !rval, "writeLocked? should be false, ie., unlocked"

		# Lock should raise errors when unlocked without first being locked.
		assert_raises( Arrow::LockingError ) { @lock.readUnlock }
		assert_raises( Arrow::LockingError ) { @lock.writeUnlock }
	end


	### Test read lock functionality
	def test_12_LockReadLocking
		printTestHeader "Session::Lock: Read locking"
		rval = nil

		# Read lock should work
		assert_nothing_raised { @lock.readLock }
		assert_nothing_raised { rval = @lock.readLocked? }
		assert rval, "readLocked? should be true, ie., read locked"
		assert_nothing_raised { rval = @lock.locked? }
		assert rval, "locked? should be true, ie., either read or write locked"
		assert_nothing_raised { rval = @lock.writeLocked? }
		assert !rval, "writeLocked? should be false, ie., not write locked"

		# readUnlock should work and leave it unlocked
		assert_nothing_raised { @lock.readUnlock }
		assert_nothing_raised { rval = @lock.readLocked? }
		assert !rval, "readLocked? should be false, ie., not locked"
		assert_nothing_raised { rval = @lock.locked? }
		assert !rval, "locked? should be false, ie., not read nor write locked"
		assert_nothing_raised { rval = @lock.writeLocked? }
		assert !rval, "writeLocked? should be false, ie., not write locked"
	end


	### Test write lock functionality
	def test_13_LockWriteLocking
		printTestHeader "Session::Lock: Read locking"
		rval = nil

		# Write lock should work
		assert_nothing_raised { @lock.writeLock }
		assert_nothing_raised { rval = @lock.writeLocked? }
		assert rval, "writeLocked? should be true, ie., write locked"
		assert_nothing_raised { rval = @lock.locked? }
		assert rval, "locked? should be true, ie., either write or read locked"
		assert_nothing_raised { rval = @lock.readLocked? }
		assert !rval, "readLocked? should be false, ie., not read locked"

		# writeUnlock should work and leave it unlocked
		assert_nothing_raised { @lock.writeUnlock }
		assert_nothing_raised { rval = @lock.writeLocked? }
		assert !rval, "writeLocked? should be false, ie., not locked"
		assert_nothing_raised { rval = @lock.locked? }
		assert !rval, "locked? should be false, ie., not write nor read locked"
		assert_nothing_raised { rval = @lock.readLocked? }
		assert !rval, "readLocked? should be false, ie., not read locked"
	end


	def test_14
		
	end
end

