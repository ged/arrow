#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Config::Path class
# $Id$
#
# Copyright (c) 2003 RubyCrafters, LLC. Most rights reserved.
# 
# This work is licensed under the Creative Commons Attribution-ShareAlike
# License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/1.0/ or send a letter to Creative
# Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
#

unless defined? Arrow::TestCase
	testsdir = File.dirname( File.expand_path(__FILE__) )
	basedir = File.dirname( testsdir )
	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/tests/lib" unless
		$LOAD_PATH.include?( "#{basedir}/tests/lib" )

	require 'arrowtestcase'
end

require 'arrow/utils'

### This test suite tests the stage1 (static) parser and the metagrammar it
### parses in which the actual parser-generator's behaviour is defined.
class Arrow::PathTestCase < Arrow::TestCase

	TestArrayPath = %w{/etc /bin /shouldnt/exist} +
		[ Dir.pwd, File.dirname(Dir.pwd) ]
	TestStringPath = TestArrayPath.join( File::PATH_SEPARATOR )
	ExtantDirs = TestArrayPath.find_all {|dir|
		File.directory?(dir) && File.readable?(dir)
	}
	warn "No extant directories in the array of test paths." if ExtantDirs.empty?


	#################################################################
	###	T E S T S
	#################################################################

	### Instance test
	def test_00_Instance
		printTestHeader "Arrow::Path: Instantiation"
		path = nil

		assert_instance_of Class, Arrow::Path
		assert_nothing_raised { path = Arrow::Path.new }
		assert_instance_of Arrow::Path, path
		assert_equal 0, path.dirs.length
	end

	### Test instantiation with a String
	def test_01_InstanceWithString
		printTestHeader "Arrow::Path: Instantiation with String"
		path, rval = nil, nil

		assert_nothing_raised {
			path = Arrow::Path.new( TestStringPath )
		}

		assert_instance_of Arrow::Path, path
		assert_instance_of Array, path.dirs
		assert_equal TestArrayPath.length, path.dirs.length

		TestArrayPath.each_with_index {|dir, i|
			assert_equal dir, path.dirs[i]
		}
	end

	### Test instantiation with a Array
	def test_02_InstanceWithArray
		printTestHeader "Arrow::Path: Instantiation with Array"
		path, rval = nil, nil

		assert_nothing_raised {
			path = Arrow::Path.new( TestArrayPath )
		}

		assert_instance_of Arrow::Path, path
		assert_instance_of Array, path.dirs
		assert_equal TestArrayPath.length, path.dirs.length

		TestArrayPath.each_with_index {|dir, i|
			assert_equal dir, path.dirs[i]
		}

		self.class.addSetupBlock {
			@path = Arrow::Path.new( TestArrayPath )
		}
		self.class.addTeardownBlock {
			@path = nil
		}
	end

	### Test the valid_dirs method
	def test_05_ValidDirs
		printTestHeader "Arrow::Path: Valid Dirs"
		rval = nil

		assert_nothing_raised {
			rval = @path.valid_dirs
		}

		assert_equal ExtantDirs, rval
	end

	### Test Enumerable interface 'each'
	def test_10_Enumerable
		printTestHeader "Arrow::Path: Each Iterator"
		rval = []
		assert_nothing_raised {
			@path.each {|dir| rval << dir}
		}
		assert_equal ExtantDirs, rval
	end

	### Test Enumerable mixin method #collect
	def test_11_EnumerableCollect
		printTestHeader "Arrow::Path: Collect Iterator"
		rval = nil
		assert_nothing_raised {
			rval = @path.collect {|dir| dir.reverse }
		}
		assert_equal ExtantDirs.collect {|dir| dir.reverse}, rval
	end

	### Test Array method delegation for #push
	def test_14_PushArrayDelegate
		printTestHeader "Arrow::Path: Array Delegate: Push"

		assert_nothing_raised {
			@path.push Dir.pwd
		}
		
		newpath = ExtantDirs + [Dir.pwd]
		assert_equal newpath, @path.valid_dirs
	end

	### Test Array method delegation for #unshift
	def test_15_UnshiftArrayDelegate
		printTestHeader "Arrow::Path: Array Delegate: Unshift"

		assert_nothing_raised {
			@path.unshift( Dir.pwd, File.dirname(Dir.pwd) )
		}
		
		newpath = [Dir.pwd, File.dirname(Dir.pwd)] + ExtantDirs 
		assert_equal newpath, @path.valid_dirs
	end

	

end

