#!/usr/bin/ruby -w
#
# Unit test for the (>>>target<<<) class
# $Id: TEMPLATE.rb.tpl,v 1.3 2003/09/17 22:30:08 deveiant Exp $
#
# Copyright (c) (>>>YEAR<<<) RubyCrafters, LLC. Most rights reserved.
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


### Collection of tests for the (>>>target<<<) class.
class (>>>target<<<)TestCase < Arrow::TestCase


	#################################################################
	###	T E S T S
	#################################################################

	### Instance test
	def test_00_Instantiate
		
	end
	
end

>>>TEMPLATE-DEFINITION-SECTION<<<
("target" "Which class does this testcase test?: ")
