#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Session::Id class
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
	testsdir = File.dirname( File.expand_path(__FILE__) )
	basedir = File.dirname( testsdir )
	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/tests/lib" unless
		$LOAD_PATH.include?( "#{basedir}/tests/lib" )

	require 'arrow/testcase'
end


### Collection of tests for the Arrow::Session::Id class.
class Arrow::SessionIdTestCase < Arrow::TestCase

	DefaultIdUri		= "md5:."
	DefaultIdType		= 'Arrow::Session::MD5Id'


	def setup
		@id = Arrow::Session::Id.create( DefaultIdUri, @req )
	end

	def teardown
		@id = nil
	end


	#################################################################
	###	T E S T S
	#################################################################

	### Test to make sure the Id class is defined
	def test_session_id_class_should_exist_and_be_a_class
		assert_block( "Arrow::Session::Id defined?" ) { defined? Arrow::Session::Id }
		assert_instance_of Class, Arrow::Session::Id
	end


	### Test the id component.
	def test_creating_an_id_should_determine_the_id_class_from_the_uri
		assert_equal DefaultIdType, @id.class.name
	end


	### Test to be sure the id object passes its own validation
	def test_11_IdValidate
		printTestHeader "Session::Id: Validation"
		rval = nil

		assert_nothing_raised {
			rval = @id.class.validate( DefaultIdUri, @id.to_s )
		}
		assert_equal @id.to_s, rval,
			"return value from .validate should be the same as its string value"

		assert_nothing_raised {
			str = @id.to_s
			str.taint
			rval = @id.class.validate( DefaultIdUri, str )
		}
		assert_not_tainted rval,
			"return value from .validate should be untainted"
	end


end

