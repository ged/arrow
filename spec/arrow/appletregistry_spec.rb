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
	require 'spec'
	require 'apache/fakerequest'
	require 'arrow'
	require 'arrow/applet'
	require 'arrow/appletregistry'
	require 'arrow/config'
	require 'spec/lib/helpers'
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
	include Arrow::SpecHelpers
	
	APPLETREGISTRY_TEST_CONFIG = {
		:applets => {
			:path			=> Arrow::Path.new( "applets:specs/data/applets" ),
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

				"/test"				=> "TestApplet",
				"/foo"				=> "BargleApplet",
			},
			:config			=> {},
		},
	}

	GEM_CONFIG = APPLETREGISTRY_TEST_CONFIG.merge({
		:gems => {
			:require_signed => false,
			:autoinstall    => false,
			:path           => Arrow::Path.new([ "gems", *Gem.path ]),
			:applets => {
				'arrow-demo-apps'       => '>= 0.0.3',
				'arrow-management-apps' => '= 0.9.4',
				'arrow-laikapedia'      => nil,
			},
		},
	})


	### Set up a stubbed applet instance that can be loaded via
	### Arrow::Applet.load.
	def fixture_appletclass( path, name, classname )
		applet = stub( "#{classname} instance (path)" )
		appletclass = stub( "#{classname} class",
			:name => name,
			:normalized_name => classname,
			:new => applet
		  )
	
		Arrow::Applet.should_receive( :load ).with( path ).once.
			and_return([ appletclass ])
		File.should_receive( :mtime ).with( path ).and_return( Time.now )
	
		return applet, appletclass
	end



	before( :all ) do
		setup_logging( :crit )
	end
	
	after( :all ) do
		reset_logging()
	end


	before( :each ) do
		Arrow::Applet.stub!( :load ).and_return( [] )
	end


	it "ignores the gem home if it isn't a directory" do
		homepath = mock( 'Pathname object for gem home' )

		Gem.should_receive( :user_home ).and_return( :user_home )
		Pathname.should_receive( :new ).with( :user_home ).and_return( homepath )
		homepath.should_receive( :+ ).with( 'gems' ).and_return( homepath )
		homepath.should_receive( :directory? ).and_return( false )

		Arrow::AppletRegistry.get_safe_gemhome.should be_nil()
	end
	

	it "ignores the gem home if it's world-writable" do
		homepath = mock( 'Pathname object for gem home' )
		homepath_stat = mock( 'Stat data for the gem home' )

		Gem.should_receive( :user_home ).and_return( :user_home )
		Pathname.should_receive( :new ).with( :user_home ).and_return( homepath )
		homepath.should_receive( :+ ).with( 'gems' ).and_return( homepath )
		homepath.should_receive( :directory? ).and_return( true )
		homepath.should_receive( :stat ).and_return( homepath_stat )

		homepath_stat.should_receive( :mode ).and_return( 0777 )

		Arrow::AppletRegistry.get_safe_gemhome.should be_nil()
	end
	

	it "returns an untainted Pathname for the gem home if it's sane" do
		homepath = mock( 'Pathname object for gem home' )
		homepath.taint
		homepath_stat = mock( 'Stat data for the gem home' )

		Gem.should_receive( :user_home ).and_return( :user_home )
		Pathname.should_receive( :new ).with( :user_home ).and_return( homepath )
		homepath.should_receive( :+ ).with( 'gems' ).and_return( homepath )
		homepath.should_receive( :directory? ).and_return( true )
		homepath.should_receive( :stat ).and_return( homepath_stat )

		homepath_stat.should_receive( :mode ).and_return( 0755 )

		rval = Arrow::AppletRegistry.get_safe_gemhome
		
		rval.should == homepath
		rval.should_not be_tainted()
	end
	

	it "loads any configured gems when it is created, and adds their template/ and applet/ " +
	   "directories to the template factory and path" do
		Gem.should_receive( :activate ).with( 'arrow-demo-apps', '>= 0.0.3' ).
			and_return( true )
		Gem.should_receive( :datadir ).with( 'arrow-demo-apps' ).
			and_return( '/some/path/arrow-demo-apps/data' )
		Gem.should_receive( :activate ).with( 'arrow-management-apps', '= 0.9.4' ).
			and_return( true )
		Gem.should_receive( :datadir ).with( 'arrow-management-apps' ).
			and_return( '/some/path/arrow-management-apps/data' )
		Gem.should_receive( :activate ).with( 'arrow-laikapedia', Gem::Requirement.default ).
			and_return( true )
		Gem.should_receive( :datadir ).with( 'arrow-laikapedia' ).
			and_return( '/some/path/arrow-laikapedia/data' )

		config = Arrow::Config.new( GEM_CONFIG )
		registry = Arrow::AppletRegistry.new( config )
		
		registry.template_factory.path.should have(5).members
		registry.template_factory.path.dirs.should include( 
			'/some/path/arrow-demo-apps/data/templates',
			'/some/path/arrow-management-apps/data/templates',
			'/some/path/arrow-laikapedia/data/templates'
		)
		
		registry.path.should have(5).members
		registry.path.dirs.should include(
			'/some/path/arrow-demo-apps/data/applets',
			'/some/path/arrow-management-apps/data/applets',
			'/some/path/arrow-laikapedia/data/applets'
		)
	end

	
	it "searches for applets in its list of paths, and loads all of them" do
		test_applet, test_appletclass = fixture_appletclass( 'test.rb', 'test', 'TestApplet' )
		bargle_applet, bargle_appletclass = fixture_appletclass( 'bargle.rb', 'bargle', 'BargleApplet' )

		File.stub!( :exist? ).and_return( true )

		Dir.should_receive( :[] ).with( 'applets/*.rb' ).and_return([ 'test.rb', 'bargle.rb' ])

		applets_path = stub( 'applets path object', :dirs => ['applets'] )
		applets_path.stub!( :each ).and_yield( 'applets' )
		config = Arrow::Config.new( APPLETREGISTRY_TEST_CONFIG )
		config.applets.path = applets_path
		registry = Arrow::AppletRegistry.new( config )

		registry.urispace.should have(2).members
		registry.urispace.values.should include( bargle_applet, test_applet )
	end
	

	describe "instance" do

		before( :all ) do
			setup_logging( :crit )
		end

	    TEST_URISPACE = {
			""                => "Setup",
			"hello"           => "Hello",
			"args"            => "ArgumentTester",
			"protected"       => "ProtectedDelegator",
			"protected/hello" => "Hello",
			"counted"         => "AccessCounter",
			"counted/hello"   => "Hello",
	    }

		before( :each ) do
			@config = Arrow::Config.new( APPLETREGISTRY_TEST_CONFIG )
			@registry = Arrow::AppletRegistry.new( @config )
			@registry.instance_variable_set( :@urispace, TEST_URISPACE )
		end
		

		it "can create an applet chain for a uri" do
			@registry.find_applet_chain( '/protected/hello' ).should have(3).members
			@registry.find_applet_chain( '/protected/hello' ).
				collect {|cl| cl.path }.should == [ '', 'protected', 'protected/hello' ]
			@registry.find_applet_chain( '/protected/hello' ).
				collect {|cl| cl.applet }.should == [ 'Setup', 'ProtectedDelegator', 'Hello' ]

			@registry.find_applet_chain( '/protected' ).should have(2).members
			@registry.find_applet_chain( '/protected' ).
				collect {|cl| cl.path }.should == [ '', 'protected' ]
			@registry.find_applet_chain( '/protected' ).
				collect {|cl| cl.applet }.should == [ 'Setup', 'ProtectedDelegator' ]

			@registry.find_applet_chain( '/' ).should have(1).members
			@registry.find_applet_chain( '/' ).
				collect {|cl| cl.path }.should == [ '' ]
			@registry.find_applet_chain( '/' ).
				collect {|cl| cl.applet }.should == [ 'Setup' ]

			@registry.find_applet_chain( '/args' ).should have(2).members
			@registry.find_applet_chain( '/args' ).
				collect {|cl| cl.path }.should == [ '', 'args' ]
			@registry.find_applet_chain( '/args' ).
				collect {|cl| cl.applet }.should == [ 'Setup', 'ArgumentTester' ]
		end


		it "reloads its applets if the configured interval has passed since applets " +
		   "were loaded" do
			# Make sure the load time is far enough in the past
			@registry.load_time = Time.now - 2000
			@registry.should_receive( :reload_applets ).once
			@registry.check_for_updates
		end
		
		it "doesn't reload its applets if the configured interval hasn't passed since " +
		   "applets were loaded" do
			# Make sure the load time is far enough in the past
			@registry.load_time = Time.now
			@registry.should_not_receive( :reload_applets )
			@registry.check_for_updates
		end
		
		it "doesn't reload its applets if reloading is turned off (interval is zero)" do
			# Make sure the load time is far enough in the past
			@config.applets.pollInterval = 0
			@registry.load_time = Time.now - 2000
			@registry.should_not_receive( :reload_applets )
			@registry.check_for_updates
		end
		
	end
	
end

