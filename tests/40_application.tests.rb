#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Application class
# $Id: 40_application.tests.rb,v 1.1 2004/03/20 18:17:40 stillflame Exp $
#
# Copyright (c) 2004 RubyCrafters, LLC. Most rights reserved.
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


### Collection of tests for the Arrow::Application class.
class Arrow::ApplicationTestCase < Arrow::TestCase


	#################################################################
	###	T E S T S
	#################################################################

	@@klass = nil
	class Foo < Arrow::Application; Signature={}; end

	### Instance test
	def test_00_Instantiate 
		assert_kind_of					Class, Foo
		assert							Foo.ancestors.include?(Arrow::Application)
	end


	def test_10_action 
		assert_nothing_raised			{ Foo.instance_eval {
											  meow = action("meow") {"meow"}
											  meow.templates = %w/ one two /
										} }
		assert							Foo.instance_methods.include?("meow_action"),
			"action not defined"
		assert							Foo.signature[:templates][:meow],
			 "signature entries missing"
		assert_equal					%w/ one two /, Foo.signature[:templates][:meow]
	end
	
	
end

