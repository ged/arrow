#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Session::Store class
# $Id$
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


### Collection of tests for the Arrow::Session::Store class.
class Arrow::SessionStoreTestCase < Arrow::TestCase

	SessionDir			= File::dirname( File::expand_path(__FILE__) ) + "/sessions"
	DefaultStoreUri		= "file:#{SessionDir}"
	DefaultStoreType	= 'Arrow::Session::FileStore'

	#################################################################
	###	T E S T S
	#################################################################

	### Instance test
	def test_00_Class
		printTestHeader "Session::Store: Class"
		
		assert_block( "Arrow::Session::Store defined?" ) { defined? Arrow::Session::Store }
		assert_instance_of Class, Arrow::Session::Store
	end


	### Test storage of simple data
	def test_10_Store
		
	end
	
end

