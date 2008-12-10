#!/usr/bin/env ruby -w
#
# Unit test for the #{vars[:applet]} applet
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

unless defined? Arrow::AppletTestCase
	require 'pathname'
	
	testsdir = Pathname.new(__FILE__).dirname.expand_path
	basedir = testsdir.parent.parent

	$LOAD_PATH.unshift( basedir + lib ) unless
		$LOAD_PATH.include?( basedir + lib )

	require 'arrow/applettestcase'
end


### Collection of tests for the #{vars[:applet]} class.
class #{vars[:applet]}TestCase < Arrow::AppletTestCase


	applet_under_test :#{vars[:applet_name]}

	#################################################################
	###	T E S T S
	#################################################################

	def test_should_do_stuff
		
	end
	
end

