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
require 'arrow/transaction'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::Transaction do
	include Arrow::SpecHelpers

	TEST_ACCEPT_HEADER = 'application/x-yaml, application/json; q=0.2, text/xml; q=0.75'


	before( :all ) do
		setup_logging( :crit )
	end

	before( :each ) do
		@options = {}
		
		@request = mock( "request object" )
		@request.stub!( :options ).and_return( @options )
		@request.stub!( :hostname ).and_return( 'testhost' )

		@headers_in  = Apache::Table.new
		@headers_out = Apache::Table.new
		@request.stub!( :headers_in ).and_return( @headers_in )
		@request.stub!( :headers_out ).and_return( @headers_out )
	end
	

	after( :all ) do
		reset_logging()
	end

	
	it "knows it's dispatched from a handler mounted at / when its request " +
		"has the root_dispatcher option set to 'yes'" do
		@options['root_dispatcher'] = 'yes'
		Arrow::Transaction.new( @request, nil, nil ).root_dispatcher?.should be_true()
	end
	
	it "knows it's dispatched from a handler mounted at / when its request " +
		"has the root_dispatcher option set to 'true'" do
		@options['root_dispatcher'] = 'true'
		Arrow::Transaction.new( @request, nil, nil ).root_dispatcher?.should be_true()
	end
	
	it "knows it's dispatched from a handler mounted at / when its request " +
		"has the root_dispatcher option set to '1'" do
		@options['root_dispatcher'] = '1'
		Arrow::Transaction.new( @request, nil, nil ).root_dispatcher?.should be_true()
	end
	
	it "knows it's not dispatched from a handler mounted at / when its request " +
		"has the root_dispatcher option set to 'false'" do
		@options['root_dispatcher'] = 'false'
		Arrow::Transaction.new( @request, nil, nil ).root_dispatcher?.should be_false()
	end

	it "knows it's not dispatched from a handler mounted at / when its request " +
		"has the root_dispatcher option set to 'no'" do
		@options['root_dispatcher'] = 'no'
		Arrow::Transaction.new( @request, nil, nil ).root_dispatcher?.should be_false()
	end

	it "knows it's not dispatched from a handler mounted at / when its request " +
		"has the root_dispatcher option set to '0'" do
		@options['root_dispatcher'] = '0'
		Arrow::Transaction.new( @request, nil, nil ).root_dispatcher?.should be_false()
	end

	it "dispatched from a root dispatcher returns an empty string for the approot" do
		@options['root_dispatcher'] = 'yes'
		Arrow::Transaction.new( @request, nil, nil ).app_root.should == ''
	end


	describe " (an instance)" do

		before( :each ) do
			@txn = Arrow::Transaction.new( @request, nil, nil )
		end


		it "knows that a form was submitted if there's a urlencoded form content-type header with a POST" do
			@headers_in[ 'content-type' ] = 'application/x-www-form-urlencoded'
			@request.should_receive( :request_method ).at_least(1).and_return( 'POST' )
			@txn.should be_a_form_request
		end

		it "knows that a form was submitted if there's a urlencoded form content-type header with a PUT" do
			@headers_in[ 'content-type' ] = 'application/x-www-form-urlencoded'
			@request.should_receive( :unparsed_uri ).and_return( '' ) # query is nil
			@request.should_receive( :request_method ).and_return( 'PUT' )
			@txn.should be_a_form_request
		end

		it "knows that a form was submitted if there's a urlencoded form content-type header with a GET" do
			@request.should_receive( :unparsed_uri ).and_return( 'foo?bar=bas&biz=boz' )
			@request.should_receive( :request_method ).and_return( 'GET' )
			@txn.should be_a_form_request
		end

		it "knows that a form was submitted if there's a urlencoded form content-type header with a DELETE" do
			@request.should_receive( :unparsed_uri ).and_return( 'foo?bar=bas&biz=boz' )
			@request.should_receive( :request_method ).and_return( 'DELETE' )
			@txn.should be_a_form_request
		end


		#it "knows that it wasn't served over secure transport if its request's schema isn't 'https'" do
		#	@request.should_receive( :unparsed_uri ).and_return( )
		#end
		

		it "should indicate a successful response when the status is 200" do
			@request.should_receive( :status ).at_least( :once ).and_return( Apache::HTTP_OK )
			@txn.is_success?.should be_true
		end

		it "should indicate a successful response when the status is 201" do
			@request.should_receive( :status ).at_least( :once ).and_return( Apache::HTTP_CREATED )
			@txn.is_success?.should be_true
		end

		it "should indicate a successful response when the status is 202" do
			@request.should_receive( :status ).at_least( :once ).and_return( Apache::HTTP_ACCEPTED )
			@txn.is_success?.should be_true
		end

		it "should indicate a non-successful response when the status is 302" do
			@request.should_receive( :status ).at_least( :once ).and_return( Apache::HTTP_MOVED_TEMPORARILY )
			@txn.is_success?.should_not be_true
		end

		it "should set its Apache status to REDIRECT when #redirect is called" do
			@request.should_receive( :status= ).with( Apache::HTTP_MOVED_TEMPORARILY )
			@txn.redirect( 'http://example.com/something' )
			@txn.handler_status.should == Apache::REDIRECT
		end

		it "delegates to the request for request methods" do
			@request.should_receive( :allowed ).and_return( :yep )
			@txn.allowed.should == :yep
		end


		it "returns the X-Forwarded-Host header if present for the value returned by #proxied_host" do
			@headers_in[ 'X-Forwarded-Host' ] = 'foo.bar.com'
			@txn.proxied_host.should == 'foo.bar.com'
		end
	
		it "returns the X-Forwarded-Server header if X-Forwarded-Host is not " +
			"present for the value returned by #proxied_host" do
			@headers_in[ 'X-Forwarded-Server' ] = 'foo.bar.com'
			@txn.proxied_host.should == 'foo.bar.com'
		end


		it "uses the proxy header for #construct_url" do
			@headers_in[ 'X-Forwarded-Host' ] = 'foo.bar.com'
			@headers_in[ 'X-Forwarded-Server' ] = 'foo.bar.com'
		
			@request.should_receive( :construct_url ).and_return( 'http://hostname/bar' )

			@txn.construct_url( "/bar" ).should == 'http://foo.bar.com/bar'
		end

		it "knows when the transaction is requested via XHR by the X-Requested-With header" do
			@headers_in[ 'X-Requested-With' ] = 'XMLHttpRequest'
			@txn.is_ajax_request?.should be_true()
		end
	
	
		it "knows when the transaction is not requested via XHR by the absence " +
			"of an X-Requested-With header" do
			@txn.is_ajax_request?.should be_false()
		end
	
		it "knows when the transaction is not requested via XHR by a non-AJAX " +
			"X-Requested-With header" do
			@headers_in[ 'X-Requested-With' ] = 'magic jellybeans of doom'
			@txn.is_ajax_request?.should be_false()
		end
	

		it "returns cookies from its headers as an Arrow::CookieSet" do
			@headers_in[ 'Cookie' ] = 'foo=12'

			# Cookies are parsed on transaction creation, so we can't use the
			# transaction that's created in the before(:each)
			txn = Arrow::Transaction.new( @request, nil, nil )

			txn.request_cookies.should be_an_instance_of( Arrow::CookieSet )
			txn.request_cookies.should include( 'foo' )
			txn.request_cookies['foo'].should be_an_instance_of( Arrow::Cookie )
		end

		it "adds Cookie headers for each cookie in a successful response" do
			@request.should_receive( :status ).
				at_least(:once).
				and_return( Apache::HTTP_OK )
		
			@headers_out.should_receive( :[]= ).with( 'Set-Cookie', /glah=locke/i ) 
			@headers_out.should_receive( :[]= ).with( 'Set-Cookie', /foo=bar/i ) 
			@headers_out.should_receive( :[]= ).with( 'Set-Cookie', /pants=velcro/i )

			@txn.cookies['glah'] = 'locke'
			@txn.cookies['foo'] = 'bar'
			@txn.cookies['pants'] = 'velcro!'
			@txn.cookies['pants'].expires = 'Sat Nov 12 22:04:00 1955'
		
			@txn.add_cookie_headers
		end
	
		it "adds Cookie error headers for each cookie in an non-OK response" do
			output_headers = mock( "output headers", :null_object => true )
			err_output_headers = mock( "error output headers", :null_object => true )
			@request.should_not_receive( :headers_out )
			@request.should_receive( :err_headers_out ).
				at_least(:once).
				and_return( err_output_headers )
			@request.should_receive( :status ).
				at_least(:once).
				and_return( Apache::REDIRECT )
		
			err_output_headers.should_receive( :[]= ).with( 'Set-Cookie', /glah=locke/i ) 
			err_output_headers.should_receive( :[]= ).with( 'Set-Cookie', /foo=bar/i ) 
			err_output_headers.should_receive( :[]= ).with( 'Set-Cookie', /pants=velcro/i )

			@txn.cookies['glah'] = 'locke'
			@txn.cookies['foo'] = 'bar'
			@txn.cookies['pants'] = 'velcro!'
			@txn.cookies['pants'].expires = 'Sat Nov 12 22:04:00 1955'
		
			@txn.add_cookie_headers
		end
	
		it "parses the 'Accept' header into one or more AcceptParam structs" do
			@headers_in['Accept'] = TEST_ACCEPT_HEADER

			@txn.accepted_types.should have( 3 ).members
			@txn.accepted_types[0].mediatype.should == 'application/x-yaml'
			@txn.accepted_types[1].mediatype.should == 'application/json'
			@txn.accepted_types[2].mediatype.should == 'text/xml'
		end
		
		it "knows what mimetypes are acceptable responses" do
			@headers_in[ 'Accept' ] = 'text/html, text/plain; q=0.5, image/*;q=0.1'

			@txn.accepts?( 'text/html' ).should be_true()
			@txn.accepts?( 'text/plain' ).should be_true()
			@txn.accepts?( 'text/ascii' ).should be_false()
			@txn.accepts?( 'image/png' ).should be_true()
			@txn.accepts?( 'application/x-yaml' ).should be_false()
		end


		it "knows what mimetypes are explicitly acceptable responses" do
			@headers_in[ 'Accept' ] = 'text/html, text/plain; q=0.5, image/*;q=0.1, */*'

			@txn.explicitly_accepts?( 'text/html' ).should be_true()
			@txn.explicitly_accepts?( 'text/plain' ).should be_true()
			@txn.explicitly_accepts?( 'text/ascii' ).should be_false()
			@txn.explicitly_accepts?( 'image/png' ).should be_false()
			@txn.explicitly_accepts?( 'application/x-yaml' ).should be_false()
		end


		it "accepts anything if the client doesn't provide an Accept header" do
			@txn.accepts?( 'text/html' ).should be_true()
			@txn.accepts?( 'text/plain' ).should be_true()
			@txn.accepts?( 'text/ascii' ).should be_true()
			@txn.accepts?( 'image/png' ).should be_true()
			@txn.accepts?( 'application/x-yaml' ).should be_true()
		end

		it "knows that the request accepts HTML if its Accept: header indicates it accepts " +
		   "'text/html'" do
			@headers_in[ 'Accept' ] = 'text/html, text/plain; q=0.5, image/*;q=0.1'
			@txn.accepts_html?.should be_true()
		end
		
		it "knows that the request accepts HTML if its Accept: header indicates it accepts " +
		   "'application/xhtml+xml'" do
			@headers_in[ 'Accept' ] = 'application/xhtml+xml, text/plain; q=0.5, image/*;q=0.1'
			@txn.accepts_html?.should be_true()
		end
		
		it "knows that the request doesn't accept HTML if its Accept: header indicates it doesn't" do
			@headers_in[ 'Accept' ] = 'text/plain; q=0.5, image/*;q=0.1'
			@txn.accepts_html?.should be_false()
		end
		

	end
end


# vim: set nosta noet ts=4 sw=4:
