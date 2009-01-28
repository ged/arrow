#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}


require 'spec'
require 'spec/lib/constants'
require 'spec/lib/helpers'
require 'spec/lib/appletmatchers'

require 'arrow'
require 'arrow/constants'
require 'arrow/service'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::Service do
	include Arrow::SpecHelpers,
	        Arrow::AppletMatchers

	before( :all ) do
		setup_logging( :debug )
	end

	after( :all ) do
		reset_logging()
	end


	before( :each ) do
		@config = stub( "Config" )
		@factory = stub( "Template factory" )
		@uri = '/service/test'

		@txn = mock( "transaction" )
		@txn.stub!( :vargs ).and_return( nil )
	end

	describe " subclass which supports only GET operations" do

		before( :each ) do
			@service_class = Class.new( Arrow::Service ) do
				def fetch( txn, id ); :one_resource; end
				def fetch_all( txn ); :resource_collection; end
			end
			@service = @service_class.new( @config, @factory, @uri )

			@txn.stub!( :uri ).and_return( @uri )
		end
		
		it "maps a GET without an ID to #fetch_all" do
			@txn.stub!( :request_method ).and_return( 'GET' )
			@service.run( @txn ).should == :resource_collection
		end
	
		it "maps a GET with an ID to #fetch" do
			@txn.stub!( :request_method ).and_return( 'GET' )
			@txn.stub!( :uri ).and_return( @uri + '/18' )
			@service.run( @txn, '18' ).should == :one_resource
		end
	
		it "maps a HEAD without an ID to #fetch_all" do
			@txn.stub!( :request_method ).and_return( 'HEAD' )
			@service.run( @txn ).should == :resource_collection
		end
	
		it "maps a HEAD with an ID to #fetch" do
			@txn.stub!( :request_method ).and_return( 'HEAD' )
			@txn.stub!( :uri ).and_return( @uri + '/18' )
			@service.run( @txn, '18' ).should == :one_resource
		end
	
		it "maps a POST to #not_allowed" do
			err_headers = mock( "error headers table" )
			@txn.stub!( :err_headers_out ).and_return( err_headers )
			err_headers.should_receive( :[]= ).with( :allow, 'GET, HEAD' )
			@txn.stub!( :request_method ).and_return( 'POST' )

			lambda {
				@service.run( @txn )
			}.should finish_with( Apache::METHOD_NOT_ALLOWED, /POST is not allowed/i )
		end
	
		it "maps a PUT to #not_allowed" do
			err_headers = mock( "error headers table" )
			@txn.stub!( :err_headers_out ).and_return( err_headers )
			err_headers.should_receive( :[]= ).with( :allow, 'GET, HEAD' )
			@txn.stub!( :request_method ).and_return( 'PUT' )

			lambda {
				@service.run( @txn )
			}.should finish_with( Apache::METHOD_NOT_ALLOWED, /PUT is not allowed/i )
		end
	
		it "maps a DELETE to #not_allowed" do
			err_headers = mock( "error headers table" )
			@txn.stub!( :err_headers_out ).and_return( err_headers )
			err_headers.should_receive( :[]= ).with( :allow, 'GET, HEAD' )
			@txn.stub!( :request_method ).and_return( 'DELETE' )

			lambda {
				@service.run( @txn )
			}.should finish_with( Apache::METHOD_NOT_ALLOWED, /DELETE is not allowed/i )
		end
	
	end

	describe " subclass which supports all operations" do

		before( :each ) do
			@service_class = Class.new( Arrow::Service ) do
				def fetch( txn, id ); :one_resource; end
				def fetch_all( txn ); :resource_collection; end
				def create( txn, id=nil ); :new_resource; end
				def update( txn ); :updated_resource; end
				def update_all( txn ); :updated_collection; end
				def delete( txn ); :deleted_resource; end
				def delete_all( txn ); :deleted_collection; end
			end
			@service = @service_class.new( @config, @factory, @uri )
			@txn.stub!( :uri ).and_return( @uri )
		end
		
		it "maps a GET without an ID to #fetch_all" do
			@txn.stub!( :request_method ).and_return( 'GET' )
			@service.run( @txn ).should == :resource_collection
		end
	
		it "maps a GET with an ID to #fetch" do
			@txn.stub!( :request_method ).and_return( 'GET' )
			@txn.stub!( :uri ).and_return( @uri + '/199' )
			@service.run( @txn, '199' ).should == :one_resource
		end
	
		it "maps a POST without an ID to #create" do
			@txn.stub!( :request_method ).and_return( 'POST' )
			@txn.stub!( :uri ).and_return( @uri )
			@service.run( @txn ).should == :new_resource
		end
	
		it "maps a POST with an ID to #create" do
			@txn.stub!( :request_method ).and_return( 'POST' )
			@txn.stub!( :uri ).and_return( @uri + '/199' )
			@service.run( @txn, '199' ).should == :new_resource
		end
	
	end

	describe " subclass whose resources have (default) simple integer IDs" do
		
		before( :each ) do
			@service_class = Class.new( Arrow::Service ) do
				def fetch( txn, id ); :one_resource; end
				def fetch_all( txn ); :resource_collection; end
				def create( txn, id=nil ); :new_resource; end
				def update( txn ); :updated_resource; end
				def update_all( txn ); :updated_collection; end
				def delete( txn ); :deleted_resource; end
				def delete_all( txn ); :deleted_collection; end
			end
			@service = @service_class.new( @config, @factory, @uri )

			@txn.stub!( :uri ).and_return( @uri )
		end
		
		it " returns a BAD_REQUEST response for a GET request with an invalid ID" do
			@txn.stub!( :request_method ).and_return( 'GET' )

			lambda {
				@service.run( @txn, 'ryanisthebest' )
			}.should finish_with( Apache::BAD_REQUEST, /invalid/i )
		end

	end


	

end

# vim: set nosta noet ts=4 sw=4:
