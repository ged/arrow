#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Broker class
# $Id: TEMPLATE.rb.tpl,v 1.3 2003/09/17 22:30:08 deveiant Exp $
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

require 'arrow/broker'
require 'arrow/utils'
require 'test/unit/mock'


### Collection of tests for the Arrow::Broker class.
class Arrow::BrokerTestCase < Arrow::TestCase

	TestConfig = {
		:noSuchAppletHandler	=> '/missing',
		:errorHandler			=> '/error',

		:applets => {
			:path			=> Arrow::Path::new( "applets:tests/applets" ),
			:pattern		=> '*.rb',
			:pollInterval	=> 5,
			:layout			=> {
				"/"				=> "Arrow::Status",
				"/missing"		=> "Arrow::NoSuchAppletHandler",
				"/error"		=> "Arrow::ErrorHandler",
				"/status"		=> "Arrow::Status",
				"/hello"		=> "Arrow::Hello",
				"/args"			=> "Arrow::ArgumentTester",

				"/foo"			=> "BargleApplet",
			},
			:config			=> {},
		},
	}

	class MockApplet < Test::Unit::MockObject( Arrow::Applet )
	end

	def setup
		@conf = Arrow::Config::new( TestConfig )
		super
	end

	def teardown
		@conf = nil
		super
	end


	#################################################################
	###	T E S T S
	#################################################################

	### Class test
	def test_00_class
		printTestHeader "Broker: Class"
		assert_instance_of Class, Arrow::Broker
		assert_instance_of Class, Arrow::Broker::RegistryEntry
	end

	
	### Instantiation
	def test_01_instantiation
		printTestHeader "Broker: Instantiation"
		rval = nil

		assert_nothing_raised { rval = Arrow::Broker::new(@conf) }
		assert_instance_of Arrow::Broker, rval

		addSetupBlock {
			@broker = Arrow::Broker::new( @conf )
		}
	end

	### Applet registry
	def test_10_registry
		printTestHeader "Broker: Applet registry"
		rval = nil

		assert_nothing_raised {
			rval = @broker.registry
		}
		assert_instance_of Hash, rval
		assert_same_keys @conf.applets.layout, rval
	end


	### Delegation
	def test_20_delegation
		printTestHeader "Broker: delegation"
		rval = nil

	end
end

