#!/usr/bin/env ruby

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
	require 'arrow/applet'
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

describe Arrow::Applet, " (subclass)" do
	before(:each) do
		@appletclass = Class.new( Arrow::Applet ) do
			def test_action( txn, *args )
				return [txn, *args]
			end
		end
		@applet = @appletclass.new( nil, nil, nil ) do
		end
	end

	
	it "doesn't use libapreq's param parser for a POST with content-type " +
	        "other than 'application/www-form-url-encoded" do
		request = mock( "request", :null_object => true )
		request.should_not_receive( :paramtable )

		txn = mock( "transaction", :null_object => true )
		txn.should_receive( :form_request? ).at_least(1).and_return( false )
		txn.stub!( :request ).and_return( request )

		@applet.run( txn, 'test' )
	end

	
	it "knows if a further subclass of it has been loaded" do
		request = mock( "request", :null_object => true )
		@appletclass.should_not be_inherited_from()
		dummyclass = Class.new( @appletclass )
		@appletclass.should be_inherited_from()
	end
	
	
	it "doesn't return superclass applets from ::load by default" do
		appletsubclass = Class.new( @appletclass )
		
		Kernel.stub!( :load ).and_return do
			Arrow::Applet.newly_loaded << @appletclass << appletsubclass
		end
		
		applets = Arrow::Applet.load( 'stubbedapplet' )
		
		applets.should_not include( @appletclass )
		applets.should include( appletsubclass )
	end
	
	
	it "returns superclass applets from ::load if asked to do so" do
		appletsubclass = Class.new( @appletclass )
		
		Kernel.stub!( :load ).and_return do
			Arrow::Applet.newly_loaded << @appletclass << appletsubclass
		end
		
		applets = Arrow::Applet.load( 'stubbedapplet', true )
		
		applets.should include( @appletclass )
		applets.should include( appletsubclass )
	end
	
	
end


# vim: set nosta noet ts=4 sw=4: