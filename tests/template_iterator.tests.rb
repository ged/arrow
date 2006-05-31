#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Template::Iterator class
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

	require 'arrowtestcase'
end


### Collection of tests for the Arrow::Template::Iterator class.
class Arrow::TemplateIteratorTestCase < Arrow::TestCase

	TestItems = [
		"Achomawi", 
		"Chemakum", 
		"Chukchansi", 
		"Clayoquot", 
		"Coast Salish", 
		"Cowichan", 
		"Haida", 
		"Hupa", 
		"Hesquiat", 
		"Karok", 
		"Klamath", 
		"Koskimo", 
		"Kwakiutl", 
		"Lummi", 
		"Makah", 
		"Nootka", 
		"Puget Sound Salish", 
		"Quileute", 
		"Quinault", 
		"Shasta", 
		"Skokomish", 
		"Tolowa", 
		"Tututni", 
		"Willapa", 
		"Wiyot", 
		"Yurok",
	]


	#################################################################
	###	T E S T S
	#################################################################

	### Test the class
	def test_00_Class
		printTestHeader "Template Iterator: Class"
		assert_instance_of Class, Arrow::Template::Iterator
	end

	### Test instantiation
	def test_01_Instantiation
		printTestHeader "Template Iterator: Instantiation"
		rval = nil

		assert_nothing_raised { rval = Arrow::Template::Iterator.new }
		assert_instance_of Arrow::Template::Iterator, rval

		assert_nothing_raised { rval = Arrow::Template::Iterator.new(TestItems[0]) }
		assert_instance_of Arrow::Template::Iterator, rval

		assert_nothing_raised { rval = Arrow::Template::Iterator.new(*TestItems) }
		assert_instance_of Arrow::Template::Iterator, rval

		addSetupBlock {
			@iter = Arrow::Template::Iterator.new(*TestItems)
		}
		addTeardownBlock {
			@iter = nil
		}
	end		

	### Test simple iteration
	def test_10_Each
		printTestHeader "Template Iterator: Simple Each"
		rval = nil

		assert_respond_to @iter, :each

		# No block should raise an error
		assert_raises( LocalJumpError ) { @iter.each }

		# Empty block is fine and should return the list
		assert_nothing_raised { rval = @iter.each {} }
		assert_equal TestItems, rval
		
		# Block should get 2 args
		rval = @iter.each do |arg1, arg2|
			assert_same @iter, arg1
			assert_instance_of String, arg2
		end
	end

	### Test iteration with multiple values yielded
	def test_15_EachMultiple
		printTestHeader "Template Iterator: Each with multiple values"
		rval = nil

		@iter.items = testhash = TestItems.collect {|str| [str, str.length]}
		
		rval = @iter.each do |iterobj, key, val|
			assert_same @iter, iterobj
			assert_instance_of String, key
			assert_instance_of Fixnum, val
			assert_equal val, key.length, "Key.length was not the same as the val arg"
		end
	end


	### Test last?
	def test_20_Last
		printTestHeader "Template Iterator: Last"

		count = 0
		@iter.each do |iter, item|
			count += 1
			if count == TestItems.length
				assert iter.last?, "Iterator#last? wasn't set for last iteration"
			else
				assert !iter.last?, "Iterator#last? was set for regular iteration"
			end
		end
	end


	### Test first?
	def test_21_First
		printTestHeader "Template Iterator: First"

		count = 0
		@iter.each do |iter, item|
			count += 1
			if count == 1
				assert iter.first?, "Iterator#first? wasn't set for first iteration"
			else
				assert !iter.first?, "Iterator#first? was set for regular iteration"
			end
		end
	end


	### Test iteration with break
	def test_30_EachWithBreak
		printTestHeader "Template Iterator: Each with Break"

		(0..TestItems.length - 1).each do |i|
			count = 0
			assert_nothing_raised {
				@iter.each do |iter, item|
					count += 1
					iter.break if iter.iteration == i
				end
			}
			assert_equal i + 1, count
		end
	end

	### Test iteration with skip
	def test_40_EachWithSkip
		printTestHeader "Template Iterator: Each with Skip"
		rval = nil

		count = 0
		@iter.each do |iter, item|
			count += 1
			assert iter.skipped?, "Iterator#skipped? was not set." if
				iter.iteration > 1
			assert_nothing_raised { iter.skip }
		end

		assert_equal( (TestItems.length / 2 + TestItems.length % 2), count )
	end


	### Test iteration with restart
	def test_50_EachWithRestart
		printTestHeader "Template Iterator: Each with Restart"
		iterations = []

		count = 0
		@iter.each do |iter, item|
			iterations.push iter.iteration
			if iter.last?
				count += 1
				iter.restart unless count >= 3
			end
		end

		assert_equal TestItems.length * 3, iterations.length,
			iterations.inspect
	end


end

