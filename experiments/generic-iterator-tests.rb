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

	require 'arrow/testcase'
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

		assert_raises( ArgumentError ) { Arrow::Template::Iterator.new }

		assert_nothing_raised {
			rval = Arrow::Template::Iterator.new( TestItems.method(:each) )
		}
		assert_instance_of Arrow::Template::Iterator, rval

		addSetupBlock {
			debugMsg "In the setup block"
			@iter = Arrow::Template::Iterator.new( TestItems.method(:each) )
			debugMsg "Done with the setup block"
		}
		addTeardownBlock {
			@iter = nil
		}
	end		

	### Test simple iteration
	def test_10_Iteration
		printTestHeader "Template Iterator: Iteration"
		rval = nil

		assert_respond_to @iter, :iterate

		# No block should raise an error
		debugMsg "About to call the no-block #iterate"
		assert_raises( LocalJumpError ) { @iter.iterate }
		debugMsg "Done with the call to the no-block #iterate"

		# Empty block is fine and should return the list
		assert_nothing_raised {
			debugMsg "Before empty block test"
			@iter.iterate do |iter, arg1|
				debugMsg "In empty block"
			end
			debugMsg "After empty block test"
		}
		
		# Block should get iter + 1 arg
		rval = @iter.iterate do |iter, arg1|
			assert_instance_of String, arg1
			assert_same @iter, iter
		end
	end


	### Test first?
	def test_21_First
		printTestHeader "Template Iterator: First"

		count = 0
		@iter.iterate do |iter, item|
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
				@iter.iterate do |iter, item|
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
		@iter.iterate do |iter, item|
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
		@iter.iterate do |iter, item|
			iterations.push iter.iteration
			if item == TestItems.last
				count += 1
				iter.restart unless count >= 3
			end
		end

		assert_equal TestItems.length * 3, iterations.length,
			iterations.inspect
	end


end

