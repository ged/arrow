#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Factory mixin
# $Id: 15_factory.tests.rb,v 1.1 2003/10/13 04:20:13 deveiant Exp $
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

require 'arrow/mixins'

### Collection of tests for the Arrow::Factory class.
class Arrow::FactoryTestCase < Arrow::TestCase


	#################################################################
	###	T E S T S
	#################################################################

	### Instance test
	def test_00_Instantiate
		
	end
	
end

