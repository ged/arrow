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
require 'arrow/service'
require 'arrow/acceptparam'


include Arrow::TestConstants

#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::Service do
	include Arrow::SpecHelpers,
	        Arrow::AppletMatchers

	before( :all ) do
		setup_logging( :crit )
	end

	after( :all ) do
		reset_logging()
	end


	before( :each ) do
		@config = stub( "Config" )
		@factory = stub( "Template factory" )
		@uri = '/service/test'
		@accepted_types = [ Arrow::AcceptParam.parse('*/*') ]

		@txn = mock( "transaction" )
		@txn.stub!( :vargs ).and_return( nil )
		@txn.stub!( :accepted_types ).and_return( @accepted_types )
		@txn.stub!( :form_request? ).and_return( false )
		@txn.stub!( :vargs= )
	end


	describe " subclass" do
		before( :all ) do
			@service_class = Class.new( Arrow::Service ) do
				public :deserialize_request_body
			end
		end
		
		before( :each ) do
			@request_headers = mock( "request headers" )
			@service = @service_class.new( @config, @factory, @uri )
			@txn.stub!( :request_method ).and_return( 'POST' )
			@txn.stub!( :headers_in ).and_return( @request_headers )
		end

		it "returns an UNSUPPORTED MEDIA TYPE response if given a body in an unsupported format" do
			@request_headers.should_receive( :[] ).with( 'content-type' ).
				and_return( 'application/x-bungtruck' )

			lambda {
				@service.deserialize_request_body( @txn )
			}.should finish_with( Apache::HTTP_UNSUPPORTED_MEDIA_TYPE, /don't know how to handle/i )
		end

		it "knows how to deserialize incoming request bodies in JSON format" do
			@request_headers.should_receive( :[] ).with( 'content-type' ).
				and_return( 'application/json' )

			JSON.should_receive( :load ).with( @txn ).and_return( :ruby_objects )
			@service.deserialize_request_body( @txn ).should == :ruby_objects
		end

		it "knows how to deserialize incoming single values from request bodies in JSON format" do
			@request_headers.should_receive( :[] ).with( 'content-type' ).
				and_return( 'application/json' )

			special_key = Arrow::Service::SPECIAL_JSON_KEY

			JSON.should_receive( :load ).with( @txn ).and_return({ special_key => 'single_value' })
			@service.deserialize_request_body( @txn ).should == 'single_value'
		end

		it "doesn't try to unwrap single-value hashes" do
			@request_headers.should_receive( :[] ).with( 'content-type' ).
				and_return( 'application/json' )

			special_key = Arrow::Service::SPECIAL_JSON_KEY
			structure = {
				'non-special-key' => 'a second value'
			}

			JSON.should_receive( :load ).with( @txn ).and_return( structure )
			@service.deserialize_request_body( @txn ).should == structure
		end

		it "doesn't try to unwrap hashes that contain the special key, but aren't just one pair" do
			@request_headers.should_receive( :[] ).with( 'content-type' ).
				and_return( 'application/json' )

			special_key = Arrow::Service::SPECIAL_JSON_KEY
			structure = {
				special_key       => 'single value',
				'non-special-key' => 'a second value'
			}

			JSON.should_receive( :load ).with( @txn ).and_return( structure )
			@service.deserialize_request_body( @txn ).should == structure
		end

		it "knows how to deserialize incoming request bodies in JSON format with a charset" do
			@request_headers.should_receive( :[] ).with( 'content-type' ).
				and_return( 'application/json; charset=UTF-8' )

			JSON.should_receive( :load ).with( @txn ).and_return( :ruby_objects )
			@service.deserialize_request_body( @txn ).should == :ruby_objects
		end

		it "knows how to deserialize incoming request bodies in YAML format" do
			@request_headers.should_receive( :[] ).with( 'content-type' ).
				and_return( 'text/x-yaml' )

			YAML.should_receive( :load ).with( @txn ).and_return( :ruby_objects )
			@service.deserialize_request_body( @txn ).should == :ruby_objects
		end

		it "knows how to deserialize incoming request bodies in marshalled format" do
			@request_headers.should_receive( :[] ).with( 'content-type' ).
				and_return( RUBY_MARSHALLED_MIMETYPE )
			Marshal.should_receive( :load ).with( @txn ).and_return( :ruby_objects )
			@service.deserialize_request_body( @txn ).should == :ruby_objects
		end

		it "knows how to deserialize incoming request bodies in " +
		   "'application/x-www-form-urlencoded' format" do
			@request_headers.should_receive( :[] ).with( 'content-type' ).
				and_return( 'application/x-www-form-urlencoded' )
			@txn.should_receive( :all_params ).and_return( :form_fields )

			@service.deserialize_request_body( @txn ).should == :form_fields
		end

		it "knows how to deserialize incoming request bodies in 'multipart/form-data' format" do
			@request_headers.should_receive( :[] ).with( 'content-type' ).
				and_return( 'multipart/form-data' )
			@txn.should_receive( :all_params ).and_return( :form_fields )

			@service.deserialize_request_body( @txn ).should == :form_fields
		end
	end
	
	describe " subclass which doesn't provide implementations of any operation" do

		before( :all ) do
			@service_class = Class.new( Arrow::Service )
		end

		before( :each ) do
			@service = @service_class.new( @config, @factory, @uri )
			@txn.stub!( :uri ).and_return( @uri )
			@err_headers = mock( "error headers table" )
			@txn.stub!( :err_headers_out ).and_return( @err_headers )
		end
		
		it "knows that it " do
			
		end
		
		it "maps a GET to #not_allowed" do
			@txn.stub!( :request_method ).and_return( 'GET' )

			@err_headers.should_receive( :[]= ).with( 'Allow', '' )
			@txn.should_receive( :status= ).with( Apache::METHOD_NOT_ALLOWED )
			@txn.should_receive( :content_type= ).with( 'text/plain' )

			@service.run( @txn ).should =~ /GET is not allowed/i
		end
	
		it "maps a GET with an ID to #not_allowed" do
			@txn.stub!( :request_method ).and_return( 'GET' )
			@txn.stub!( :uri ).and_return( @uri + '/18' )

			@err_headers.should_receive( :[]= ).with( 'Allow', '' )
			@txn.should_receive( :status= ).with( Apache::METHOD_NOT_ALLOWED )
			@txn.should_receive( :content_type= ).with( 'text/plain' )

			@service.run( @txn ).should =~ /GET is not allowed/i
		end
	
		it "maps a HEAD without an ID to #not_allowed" do
			@txn.stub!( :request_method ).and_return( 'HEAD' )

			@err_headers.should_receive( :[]= ).with( 'Allow', '' )
			@txn.should_receive( :status= ).with( Apache::METHOD_NOT_ALLOWED )
			@txn.should_receive( :content_type= ).with( 'text/plain' )

			@service.run( @txn ).should =~ /HEAD is not allowed/i
		end
	
		it "maps a HEAD with an ID to #not_allowed" do
			@txn.stub!( :request_method ).and_return( 'HEAD' )
			@txn.stub!( :uri ).and_return( @uri + '/18' )

			@err_headers.should_receive( :[]= ).with( 'Allow', '' )
			@txn.should_receive( :status= ).with( Apache::METHOD_NOT_ALLOWED )
			@txn.should_receive( :content_type= ).with( 'text/plain' )

			@service.run( @txn ).should =~ /HEAD is not allowed/i
		end
	
		it "maps a POST to #not_allowed" do
			@txn.stub!( :request_method ).and_return( 'POST' )

			@err_headers.should_receive( :[]= ).with( 'Allow', '' )
			@txn.should_receive( :status= ).with( Apache::METHOD_NOT_ALLOWED )
			@txn.should_receive( :content_type= ).with( 'text/plain' )

			@service.run( @txn ).should =~ /POST is not allowed/i
		end
	
		it "maps a PUT to #not_allowed" do
			@err_headers = mock( "error headers table" )
			@txn.stub!( :err_headers_out ).and_return( @err_headers )
			@txn.stub!( :request_method ).and_return( 'PUT' )

			@err_headers.should_receive( :[]= ).with( 'Allow', '' )
			@txn.should_receive( :status= ).with( Apache::METHOD_NOT_ALLOWED )
			@txn.should_receive( :content_type= ).with( 'text/plain' )

			@service.run( @txn ).should =~ /PUT is not allowed/i
		end
	
		it "maps a DELETE to #not_allowed" do
			@err_headers = mock( "error headers table" )
			@txn.stub!( :err_headers_out ).and_return( @err_headers )
			@txn.stub!( :request_method ).and_return( 'DELETE' )

			@err_headers.should_receive( :[]= ).with( 'Allow', '' )
			@txn.should_receive( :status= ).with( Apache::METHOD_NOT_ALLOWED )
			@txn.should_receive( :content_type= ).with( 'text/plain' )

			@service.run( @txn ).should =~ /DELETE is not allowed/i
		end
	
	end

	describe " subclass which provides implementations of all operations" do
		before( :all ) do
			@service_class = Class.new( Arrow::Service ) do
				def fetch( txn, id ); :one_resource; end
				def fetch_all( txn ); :resource_collection; end
				def create( txn, id=nil ); :new_resource; end
				def update( txn, id ); :updated_resource; end
				def update_all( txn ); :updated_collection; end
				def delete( txn, id ); :deleted_resource; end
				def delete_all( txn ); :deleted_collection; end
			end
		end

		before( :each ) do
			@service = @service_class.new( @config, @factory, @uri )
			@txn.stub!( :uri ).and_return( @uri )
			@txn.stub!( :content_type ).and_return( 'application/x-rubyobject' )
			@txn.stub!( :accepts? ).and_return( true )
			@txn.stub!( :normalized_accept_string ).and_return( "acceptable types" )
			@txn.stub!( :status ).and_return( nil )
		end

		
		it "maps a GET without an ID to #fetch_all" do
			@txn.stub!( :request_method ).and_return( 'GET' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn ).should == :resource_collection
		end
	
		it "maps a GET with an ID to #fetch" do
			@txn.stub!( :request_method ).and_return( 'GET' )
			@txn.stub!( :uri ).and_return( @uri + '/199' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn, '199' ).should == :one_resource
		end
	
		it "maps a POST without an ID to #create" do
			@txn.stub!( :request_method ).and_return( 'POST' )
			@txn.stub!( :uri ).and_return( @uri )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn ).should == :new_resource
		end
	
		it "maps a POST with an ID to #create" do
			@txn.stub!( :request_method ).and_return( 'POST' )
			@txn.stub!( :uri ).and_return( @uri + '/199' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn, '199' ).should == :new_resource
		end
	
		it "maps a PUT without an ID to #update_all" do
			@txn.stub!( :request_method ).and_return( 'PUT' )
			@txn.stub!( :uri ).and_return( @uri )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn ).should == :updated_collection
		end
	
		it "maps a PUT with an ID to #update" do
			@txn.stub!( :request_method ).and_return( 'PUT' )
			@txn.stub!( :uri ).and_return( @uri + '/199' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn, '199' ).should == :updated_resource
		end
	
		it "maps a DELETE without an ID to #delete_all" do
			@txn.stub!( :request_method ).and_return( 'DELETE' )
			@txn.stub!( :uri ).and_return( @uri )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn ).should == :deleted_collection
		end
	
		it "maps a DELETE with an ID to #delete" do
			@txn.stub!( :request_method ).and_return( 'DELETE' )
			@txn.stub!( :uri ).and_return( @uri + '/199' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn, '199' ).should == :deleted_resource
		end
	
	end

	describe " subclass which supports resource operations" do
		before( :all ) do
			@service_class = Class.new( Arrow::Service ) do
				def fetch_test( txn, id ); :one_resource_test; end
				def fetch_test_subresource( txn, id ); :one_resource_test_subresource; end
				def create_test( txn, id=nil ); :new_resource_test; end
				def update_test( txn, id ); :updated_resource_test; end
				def delete_test( txn, id ); :deleted_resource_test; end
				def delete_test_subresource( txn, id ); :deleted_resource_test_subresource; end
				def validate_id( id ); return id; end
			end
		end

		before( :each ) do
			@service = @service_class.new( @config, @factory, @uri )
			@txn.stub!( :uri ).and_return( @uri )
			@txn.stub!( :content_type ).and_return( 'application/x-rubyobject' )
			@txn.stub!( :accepts? ).and_return( true )
			@txn.stub!( :normalized_accept_string ).and_return( "acceptable types" )
			@txn.stub!( :status ).and_return( nil )
		end

		
		it "maps a GET with an ID and one operation to #fetch_«operation»" do
			@txn.stub!( :request_method ).and_return( 'GET' )
			@txn.stub!( :uri ).and_return( @uri + '/199/test' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn, '199', 'test' ).should == :one_resource_test
		end
	
		it "maps a GET with an ID and two operations to #fetch_«op1»_«op2»" do
			@txn.stub!( :request_method ).and_return( 'GET' )
			@txn.stub!( :uri ).and_return( @uri + '/199/test/subresource' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn, '199', 'test', 'subresource' ).
				should == :one_resource_test_subresource
		end
	
		it "maps a DELETE with an ID and two operations to #fetch_«op1»_«op2»" do
			@txn.stub!( :request_method ).and_return( 'DELETE' )
			@txn.stub!( :uri ).and_return( @uri + '/199/test/subresource' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn, '199', 'test', 'subresource' ).
				should == :deleted_resource_test_subresource
		end
	
		it "maps a POST with an ID and operation to #create_«operation»" do
			@txn.stub!( :request_method ).and_return( 'POST' )
			@txn.stub!( :uri ).and_return( @uri + '/199/test' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn, '199', 'test' ).should == :new_resource_test
		end
	
		it "maps a PUT with an ID and operation to #update_«operation»" do
			@txn.stub!( :request_method ).and_return( 'PUT' )
			@txn.stub!( :uri ).and_return( @uri + '/199/test' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn, '199', 'test' ).should == :updated_resource_test
		end
	
		it "maps a DELETE with an ID and operation to #delete_«operation»" do
			@txn.stub!( :request_method ).and_return( 'DELETE' )
			@txn.stub!( :uri ).and_return( @uri + '/fookles/test' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			@service.run( @txn, 'fookles', 'test' ).should == :deleted_resource_test
		end
	
	end

	describe " subclass whose resources have (default) simple integer IDs" do
		
		before( :all ) do
			@service_class = Class.new( Arrow::Service ) do
				def fetch( txn, id ); :one_resource; end
				def fetch_all( txn ); :resource_collection; end
				def create( txn, id=nil ); :new_resource; end
				def update( txn ); :updated_resource; end
				def update_all( txn ); :updated_collection; end
				def delete( txn ); :deleted_resource; end
				def delete_all( txn ); :deleted_collection; end
			end
		end
		
		before( :each ) do
			@service = @service_class.new( @config, @factory, @uri )
			@txn.stub!( :uri ).and_return( @uri )
			@txn.stub!( :content_type ).and_return( 'text/plain' )
			@txn.stub!( :accepts? ).and_return( true )
			@txn.stub!( :normalized_accept_string ).and_return( "acceptable types" )
		end
		
		it " returns a BAD_REQUEST response for a GET request with an invalid ID" do
			@txn.stub!( :request_method ).and_return( 'GET' )
			@txn.stub!( :explicitly_accepts? ).and_return( false )
			@txn.stub!( :accepts_html? ).and_return( false )
			@txn.should_receive( :status= ).with( Apache::BAD_REQUEST )
			@txn.should_receive( :content_type= ).with( 'text/plain' )
			
			@service.run( @txn, 'ryanisthebest' ).should =~ /invalid id/i
		end

	end

	TEST_SERVICE_OBJECTS = [
		{
			:name => 'object1',
			:key1 => 'value1',
			:key2 => 'value2',
			:key3 => 'value3',
		},
		{
			:name => 'object2',
			:key1 => 'value4',
			:key2 => 'value5',
			:key3 => 'value6',
		},
	]
  
	describe "subclass which returns Ruby objects" do
		before( :all ) do
			@service_class = Class.new( Arrow::Service ) do
				def initialize( *args )
					@objects = TEST_SERVICE_OBJECTS.dup
					super
				end

				attr_reader :objects
				
				def fetch( txn, id )
					return @objects[ id - 1 ]
				end
				def fetch_all( txn )
					return @objects
				end
			end
		end
		
		before( :each ) do
			@request_headers = mock( "request headers" )
			@response_headers = mock( "response headers" )
			@error_headers = mock( "error headers" )

			@service = @service_class.new( @config, @factory, @uri )

			@txn.stub!( :uri ).and_return( @uri )
			@txn.stub!( :request_method ).and_return( 'GET' )
			@txn.stub!( :headers_out ).and_return( @response_headers )
			@txn.stub!( :headers_in ).and_return( @request_headers )
			@txn.stub!( :err_headers_out ).and_return( @error_headers )

			@txn.stub!( :content_type ).and_return( nil )
			@txn.stub!( :accepts? ).and_return( true )
			@txn.stub!( :explicitly_accepts? ).and_return( false )
			@txn.stub!( :normalized_accept_string ).and_return( "acceptable types" )
			@txn.stub!( :status ).and_return( nil )
		end
		
		it "serves a single fetched object as HTML if the request doesn't specify acceptable " +
		   "content types" do
			template = mock( "service template" ).as_null_object
			@factory.should_receive( :get_template ).and_return( template )

			@txn.stub!( :explicitly_accepts? ).and_return( false )
			@txn.should_receive( :accepts_html? ).and_return( true )
			@txn.should_receive( :content_type= ).with( HTML_MIMETYPE )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			template.should_receive( :body= ).with( /value4/ )

			@service.run( @txn, '2' ).should == template
		end
		
		it "serves an object collection as HTML if the request doesn't specify acceptable " +
		   "content types" do
			template = mock( "service template" ).as_null_object
			@factory.should_receive( :get_template ).and_return( template )

			@txn.stub!( :explicitly_accepts? ).and_return( false )
			@txn.should_receive( :accepts_html? ).and_return( true )
			@txn.should_receive( :content_type= ).with( HTML_MIMETYPE )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )
			template.should_receive( :body= ).with( /value4/ )

			@service.run( @txn ).should == template
		end

		it "serves a single fetched object as JSON if the request prefers it" do
			@txn.stub!( :explicitly_accepts? ).with( 'application/json' ).
				and_return( true )
			@txn.should_receive( :content_type= ).with( 'application/json' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )

			@service.objects[1].should_receive( :to_json ).and_return( :json_object2 )
				
			@txn.should_not_receive( :accepts_html? ).and_return( true )

			@service.run( @txn, '2' ).should == :json_object2
		end
		
		it "serves an object collection as JSON if the request prefers it" do
			@txn.stub!( :explicitly_accepts? ).with( 'application/json' ).
				and_return( true )
			@txn.should_receive( :content_type= ).with( 'application/json' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )

			@txn.should_not_receive( :accepts_html? ).and_return( true )

			@service.objects.should_receive( :to_json ).and_return( :json_object_collection )
				
			@service.run( @txn ).should == :json_object_collection
		end

		it "serves a single fetched object as YAML if the request prefers it" do
			@txn.stub!( :explicitly_accepts? ).with( 'text/x-yaml' ).
				and_return( true )
			@txn.should_receive( :content_type= ).with( 'text/x-yaml' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )

			@service.objects[1].should_receive( :to_yaml ).and_return( :yaml_object2 )

			@txn.should_not_receive( :accepts_html? ).and_return( true )

			@service.run( @txn, '2' ).should == :yaml_object2
		end
		
		it "serves an object collection as YAML if the request prefers it" do
			@txn.stub!( :explicitly_accepts? ).with( 'text/x-yaml' ).
				and_return( true )
			@txn.should_receive( :content_type= ).with( 'text/x-yaml' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )

			@txn.should_not_receive( :accepts_html? ).and_return( true )

			@service.objects.should_receive( :to_yaml ).and_return( :yaml_object_collection )

			@service.run( @txn ).should == :yaml_object_collection
		end

		it "serves a single fetched object as XML if the request prefers it" do
			@txn.stub!( :explicitly_accepts? ).with( 'text/xml' ).
				and_return( true )
			@txn.should_receive( :content_type= ).with( 'text/xml' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )

			@service.objects[1].should_receive( :to_xml ).and_return( :xml_object2 )

			@txn.should_not_receive( :accepts_html? ).and_return( true )

			@service.run( @txn, '2' ).should == :xml_object2
		end
		
		it "serves an object collection as XML if the request prefers it" do
			@txn.stub!( :explicitly_accepts? ).with( 'text/xml' ).
				and_return( true )
			@txn.should_receive( :content_type= ).with( 'text/xml' )
			@txn.should_receive( :status= ).with( Apache::HTTP_OK )

			@txn.should_not_receive( :accepts_html? ).and_return( true )

			@service.objects.should_receive( :to_xml ).and_return( :xml_object_collection )

			@service.run( @txn ).should == :xml_object_collection
		end

	end

end

# vim: set nosta noet ts=4 sw=4:
