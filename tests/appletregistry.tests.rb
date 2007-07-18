#!/usr/bin/env ruby
# 
# Unit test for the Arrow::AppletRegistry class
# $Id: broker.tests.rb 183 2004-08-23 06:10:32Z ged $
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
	testsdir = File.dirname( File.expand_path(__FILE__) )
	basedir = File.dirname( testsdir )
	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/tests/lib" unless
		$LOAD_PATH.include?( "#{basedir}/tests/lib" )

	require 'arrow/testcase'
end

require 'arrow/appletregistry'
require 'arrow/utils'


### Collection of tests for the Arrow::Broker class.
class Arrow::AppletRegistry::TestCase < Arrow::TestCase

	TestConfig = {
		:applets => {
			:path			=> Arrow::Path.new( "applets:tests/applets" ),
			:pattern		=> '*.rb',
			:pollInterval	=> 5,
			:missingApplet	=> '/missing',
			:errorApplet	=> '/error',

			:layout			=> {
				"/"					=> "Setup",
				"/missing"			=> "NoSuchAppletHandler",
				"/error"			=> "ErrorHandler",
				"/status"			=> "ServerStatus",
				"/hello"			=> "Hello",
				"/args"				=> "ArgumentTester",
				"/protected"		=> "ProtectedDelegator",
				"/protected/hello"	=> "Hello",
				"/counted"			=> "AccessCounter",
				"/counted/hello"	=> "Hello",

				"/test"				=> "TestingApplet",
				"/foo"				=> "BargleApplet",
			},
			:config			=> {},
		},
	}

	def setup
		@conf = Arrow::Config.new( TestConfig )
		@registry = Arrow::AppletRegistry.new( @conf )
		super
	end


	#################################################################
	###	T E S T S
	#################################################################

	def test_registry_by_uri_should_have_same_keys_as_config
        registry = Arrow::AppletRegistry.new( @conf )
		assert_same_keys @conf.applets.layout, registry.urispace
	end


    TestUris = {
		"/"					=> ["Setup"],
		""					=> ["Setup"],
		"/hello"			=> ["Setup", "Hello"],
		"/args"				=> ["Setup", "ArgumentTester"],
		"/protected"		=> ["Setup", "ProtectedDelegator"],
		"/protected/hello"	=> ["Setup", "ProtectedDelegator", "Hello"],
		"/counted"			=> ["Setup", "AccessCounter"],
		"/counted/hello"	=> ["Setup", "AccessCounter", "Hello"],
    }

    def test_registry_should_create_chain_for_valid_uris
        chain = nil
        
        TestUris.each do |uri, classname|
            assert_nothing_raised do
                chain = @registry.find_applet_chain( uri )
            end
            
            assert_instance_of Array, chain
            debugMsg "Applet chain for %p = %p" % [uri, chain]
			assert_equal TestUris[ uri ].length, chain.length,
				"links in chain for uri %p" % [uri]

            TestUris[ uri ].each_with_index do |appletname, i|
				assert_kind_of Struct, chain[i], "link %d in chain %p for uri %p" %
					[ i, chain, uri ]
                assert_equal appletname, chain[i][0].class.normalized_name
            end
        end
    end

end

