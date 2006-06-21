#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Dispatcher class
# $Id: broker.tests.rb 282 2006-04-13 00:48:28Z ged $
#
# Copyright (c) 2004, 2006 RubyCrafters, LLC. Most rights reserved.
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

require 'arrow/dispatcher'
require 'arrow/utils'


### Collection of tests for the Arrow::Dispatcher class.
class Arrow::DispatcherTestCase < Arrow::TestCase


	#################################################################
	###	T E S T S
	#################################################################

    def test_creation_with_a_filename_should_load_configuration_and_assign_to_default
		res = nil

		assert_nothing_raised do
			res = Arrow::Dispatcher.create( "tests/data/test.cfg" )
		end
		
		assert_instance_of Arrow::Dispatcher, res
    end


	
end

