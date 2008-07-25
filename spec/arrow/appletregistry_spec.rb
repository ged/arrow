#!/usr/bin/env ruby
# 
# Specification for the Arrow::Applet class
# $Id$
#
# Copyright (c) 2004-2008 The FaerieMUD Consortium. Most rights reserved.
# 

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'apache/fakerequest'
	require 'arrow'
	require 'arrow/appletregistry'
	require 'arrow/spechelpers'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::AppletRegistry do
	
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

