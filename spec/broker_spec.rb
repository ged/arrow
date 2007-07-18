#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'apache/fakerequest'
	require 'arrow'
	require 'arrow/spechelpers'
	require 'arrow/broker'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


module FixtureFunctions
	ChainLink = Arrow::AppletRegistry::ChainLink
	
	TEST_CONFIG = {
		:applets => {
			:path			=> Arrow::Path.new( "" ),
			:pattern		=> '*.rb',
			:pollInterval	=> 0,
			:missingApplet	=> '/missing',
			:errorApplet	=> '/error',

			:layout			=> {},
			:config			=> {},
		},
	}
	
	def make_applet_chain( uri, *applets )
		chain = []
		uriparts = uri.split( %r{/} )

		applets.each_with_index do |applet, i|
			chain << ChainLink.new(
				applet,
				uriparts[0..i+1].join('/'),
				uriparts[i+2 .. -1] || []
			  )
		end
		
		return chain
	end
end



#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::Broker do
	include FixtureFunctions
	
	# before( :all ) do
	# 	Arrow::Logger.global.outputters << Arrow::Logger::Outputter.create( 'color:stderr', self )
	# 	Arrow::Logger.global.level = :debug
	# end
	# 
	# after( :all ) do
	# 	Arrow::Logger.global.level = :error
	# end
	
	before( :each ) do
		conf = Arrow::Config.new( TEST_CONFIG )
		@broker = Arrow::Broker.new( conf )
	end

	

	it "runs an applet when dispatching a uri that maps to it" do
		applet = mock( "applet", :null_object => true )
		appletchain = make_applet_chain( '/admin/create/job/1', applet )
		@broker.registry = stub( "applet registry",
			:check_for_updates => true,
			:find_applet_chain => appletchain
		  )

		txn = mock( "transaction", :null_object => true )
		txn.should_receive( :path ).and_return( '/admin/create/job/1' )

		applet.should_receive( :run ).
			with( txn, "create", "job", "1" ).
			and_return( :passed )

		@broker.delegate( txn ).should == :passed
	end

	
	it "chains calls through multiple applets when a uri maps to more than one" do
		applet1 = mock( "delegating applet 1" )
		applet2 = mock( "delegating applet 2" )
		applet3 = mock( "target applet" )

		appletchain = make_applet_chain( '/admin/create/job/1', applet1, applet2, applet3 )
		@broker.registry = stub( "applet registry",
			:check_for_updates => true,
			:find_applet_chain => appletchain
		  )

		txn = mock( "transaction", :null_object => true )
		txn.should_receive( :path ).and_return( '/admin/create/job/1' )
		signature = stub( "applet signature", :name => 'mock applet' )

		applet1.should_receive( :signature ).
			at_least(:once).
			and_return( signature )
		applet1.should_receive( :delegate ).
			with( txn, appletchain[1,2], "create", "job", "1" ).
			and_yield( nil )
		applet2.should_receive( :signature ).
			at_least(:once).
			and_return( signature )
		applet2.should_receive( :delegate ).
			with( txn, appletchain[2..2], "job", "1" ).
			and_yield( nil )
		applet3.should_receive( :signature ).
			at_least(:once).
			and_return( signature )
		applet3.should_receive( :run ).
			with( txn, "1" ).
			and_return( :passed )

		@broker.delegate( txn ).should == :passed
	end
end


describe Arrow::Broker, " for a root-mounted dispatcher" do
	include FixtureFunctions

	it "runs the root applet for a request to an empty path" do
		conf = Arrow::Config.new( TEST_CONFIG )
		broker = Arrow::Broker.new( conf )

		applet = mock( "applet", :null_object => true )
		appletchain = make_applet_chain( '/', applet )
		broker.registry = stub( "applet registry",
			:check_for_updates => true,
			:find_applet_chain => appletchain
		  )

		txn = mock( "transaction", :null_object => true )
		txn.should_receive( :path ).and_return( '' )

		applet.should_receive( :run ).
			with( txn ).
			and_return( :passed )

		broker.delegate( txn ).should == :passed
	end
end


