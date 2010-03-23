#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'spec'
require 'spec/lib/helpers'

require 'apache/fakerequest'

require 'arrow'
require 'arrow/dispatcherloader'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::DispatcherLoader do
	include Arrow::SpecHelpers


	before( :all ) do
		setup_logging( :crit )
	end

	after( :all ) do
		reset_logging()
	end

	it "creates Arrow::Dispatchers from a registered configfile on child_init" do
		req = Apache::Request.new
		Arrow::Dispatcher.should_receive( :create_from_hosts_file ).with( 'hosts.yml' )
		Arrow::DispatcherLoader.new( 'hosts.yml' ).child_init( req ).should == Apache::OK
	end

	it "handles errors while loading dispachers by logging to a tempfile and to Apache's log" do
		req = Apache::Request.new
		Arrow::Dispatcher.should_receive( :create_from_hosts_file ).with( 'hosts.yml' ).
			and_raise( RuntimeError.new("something bad happened") )

		logpath = mock( "error logfile Pathname" )
		io = mock( "error logfile IO" )

		Pathname.should_receive( :new ).with( instance_of(String) ).
			and_return( logpath )
		logpath.should_receive( :+ ).with( 'arrow-dispatcher-failure.log' ).and_return( logpath )
		logpath.should_receive( :open ).with( IO::WRONLY|IO::TRUNC|IO::CREAT ).and_yield( io )
		io.should_receive( :puts ).with( /something bad happened/ )
		io.should_receive( :flush )

		expect {
			Arrow::DispatcherLoader.new( 'hosts.yml' ).child_init( req )
		}.to raise_error( RuntimeError, /something bad happened/ )
	end


end

