#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Applet class
# $Id$
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


### Collection of tests for the Arrow::Applet class.
class Arrow::AppletTestCase < Arrow::TestCase


	#################################################################
	###	T E S T S
	#################################################################

	### Instance test
	def test_00_Define
		printTestHeader "Applet: Define"
		applet = rval = nil

		# Make a new Applet class
		assert_nothing_raised {
			applet = Class::new( Arrow::Applet ) {
				@signature = {}
			}
		}

		# Make sure the class is what we expect
		assert_kind_of Class, applet
		assert applet.ancestors.include?( Arrow::Applet )

		addSetupBlock {
			@appletClass = Class::new( Arrow::Applet ) {
				@signature = {}
			}
		}
		addTeardownBlock {
			@appletClass = nil
		}
	end


	def test_30_action_function
		printTestHeader "Applet: Define actions via action() function"
		rval = meow = nil

		# Definition only
		assert_nothing_raised {
			@appletClass.instance_eval {
				action( "woof" ) { "woof" }
			}
		}

		assert_has_instance_method @appletClass, :woof_action

		# With Proxy
		assert_nothing_raised {
			@appletClass.instance_eval {
				meow = action("meow") {"meow"}
				meow.template = 'one.tmpl'
			}
		}

		assert_instance_of Arrow::Applet::SigProxy, meow
		assert_has_instance_method @appletClass, :meow_action
		assert_not_nil @appletClass.signature[:templates][:meow], "signature entries missing"
		assert_equal 'one.tmpl', @appletClass.signature[:templates][:meow]
	end
	
	
	def test_31_action_function_symbol_arg
		printTestHeader "Applet: Define actions via action() function (Symbol arg)"
		rval = meow = nil

		# Definition only
		assert_nothing_raised {
			@appletClass.instance_eval {
				action( :woof ) { "woof" }
			}
		}

		assert_has_instance_method @appletClass, :woof_action

		# With Proxy
		assert_nothing_raised {
			@appletClass.instance_eval {
				meow = action(:meow) {"meow"}
				meow.template = 'one.tmpl'
			}
		}

		assert_instance_of Arrow::Applet::SigProxy, meow
		assert_has_instance_method @appletClass, :meow_action
		assert_not_nil @appletClass.signature[:templates][:meow], "signature entries missing"
		assert_equal 'one.tmpl', @appletClass.signature[:templates][:meow]
	end
	
	
end

