#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Broker class
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

require 'arrow/broker'
require 'arrow/utils'
require 'test/unit/mock'


### Collection of tests for the Arrow::Broker class.
class Arrow::BrokerTestCase < Arrow::TestCase

	TestConfig = {
		:applets => {
			:path			=> Arrow::Path::new( "applets:tests/applets" ),
			:pattern		=> '*.rb',
			:pollInterval	=> 5,
			:missingApplet	=> '/missing',
			:errorApplet	=> '/error',
			:defaultApplet	=> '/status',

			:layout			=> {
				"/"					=> "Setup",
				"/missing"			=> "NoSuchAppletHandler",
				"/error"			=> "ErrorHandler",
				"/status"			=> "ServerStatus",
				"/hello"			=> "HelloWorld",
				"/args"				=> "ArgumentTester",
				"/protected"		=> "ProtectedDelegator",
				"/protected/hello"	=> "HelloWorld",
				"/counted"			=> "AccessCounter",
				"/counted/hello"	=> "HelloWorld",

				"/test"				=> "TestingApplet",
				"/foo"				=> "BargleApplet",
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
	def test_20_find_applet_chain
		printTestHeader "Broker: find applet chain"
		rval = nil

		{
			"/"					=> [ [/Setup/, "", []] ],
			"/status"			=> [
				[/Setup/, "", ["status"]],
				[/ServerStatus/, "status", []],
			],
			"/missing"			=> [
				[/Setup/, "", ["missing"]],
				[/NoSuchAppletHandler/, "missing", []],
			],
			"/error"			=> [
				[/Setup/, "", ["error"]],
				[/ErrorHandler/, "error", []],
			],
			"/status"			=> [
				[/Setup/, "", ["status"]],
				[/ServerStatus/, "status", []],
			],
			"/hello"			=> [
				[/Setup/, "", ["hello"]],
				[/HelloWorld/, "hello", []],
			],
			"/args"				=> [
				[/Setup/, "", ["args"]],
				[/ArgumentTester/, "args", []],
			],
			"/protected"		=> [
				[/Setup/, "", ["protected"]],
				[/ProtectedDelegator/, "protected", []],
			],
			"/protected/hello"	=> [
				[/Setup/, "", ["protected", "hello"]],
				[/ProtectedDelegator/, "protected", ["hello"]],
				[/HelloWorld/, "protected/hello", []],
			],
			"/counted"		=> [
				[/Setup/, "", ["counted"]],
				[/AccessCounter/, "counted", []],
			],
			"/counted/hello"	=> [
				[/Setup/, "", ["counted", "hello"]],
				[/AccessCounter/, "counted", ["hello"]],
				[/HelloWorld/, "counted/hello", []],
			],
		}.each do |uri, res|
			msg = "'%s' => %p" % [ uri, res ]

			assert_nothing_raised( msg ) {
				rval = @broker.__send__( :findAppletChain, uri )
			}
			assert_instance_of Array, rval,
				"applet chain is an array for '%s'" % uri
			assert_equal res.length, rval.length,
				"applet chain contains the right number of links for '%s'" % uri

			rval.each_with_index {|link, i|
				assert_instance_of Arrow::Broker::RegistryEntry, link.first
				assert_instance_of Array, link.last

				assert_match res[i].first, link.first.appletclass.name,
					"registry entry applet class name"
				assert_instance_of link.first.appletclass, link.first.object
				assert_equal res[i][1], link[1]
				assert_equal res[i].last, link.last
			}

		end
	end
end

