#!/usr/bin/env ruby -w
#
# Unit test for the #{vars[:target_class]} class
# $Id$
#
# Copyright (c) (#{date.year}) RubyCrafters, LLC. Most rights reserved.
# 
# This work is licensed under the Creative Commons Attribution-ShareAlike
# License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/1.0/ or send a letter to Creative
# Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
#
# 

unless defined? Arrow::TestCase
	require 'pathname'
	
	testsdir = Pathname.new(__FILE__).dirname.expand_path
	basedir = testsdir.parent

	$LOAD_PATH.unshift( basedir + lib ) unless
		$LOAD_PATH.include?( basedir + lib )

	require 'arrow/testcase'
end


### Collection of tests for the #{vars[:target_class]} class.
class #{vars[:target_class]}TestCase < Arrow::TestCase


	#################################################################
	###	T E S T S
	#################################################################

	def test_should_do_stuff
		
	end
	
end

