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
	require 'arrow/transaction'
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

describe Arrow::Transaction do
	it "knows it's dispatched from a handler mounted at / when its request " +
		"has the root_dispatcher option set to 'yes'" do
		request = mock( "request object", :null_object => true )
		request.should_receive( :options ).at_least(:once).
			and_return({ 'root_dispatcher' => 'yes' })
		txn = Arrow::Transaction.new( request, nil, nil )
		
		txn.root_dispatcher?.should be_true()
	end
	
	it "knows it's dispatched from a handler mounted at / when its request " +
		"has the root_dispatcher option set to 'true'" do
		request = mock( "request object", :null_object => true )
		request.should_receive( :options ).at_least(:once).
			and_return({ 'root_dispatcher' => 'true' })
		txn = Arrow::Transaction.new( request, nil, nil )
		
		txn.root_dispatcher?.should be_true()
	end
	
	it "knows it's dispatched from a handler mounted at / when its request " +
		"has the root_dispatcher option set to '1'" do
		request = mock( "request object", :null_object => true )
		request.should_receive( :options ).at_least(:once).
			and_return({ 'root_dispatcher' => '1' })
		txn = Arrow::Transaction.new( request, nil, nil )
		
		txn.root_dispatcher?.should be_true()
	end
	
	it "knows it's not dispatched from a handler mounted at / when its request " +
		"has the root_dispatcher option set to 'false'" do
		request = mock( "request object", :null_object => true )
		request.should_receive( :options ).at_least(:once).
			and_return({ 'root_dispatcher' => 'false' })
		txn = Arrow::Transaction.new( request, nil, nil )
		
		txn.root_dispatcher?.should be_false()
	end

	it "knows it's not dispatched from a handler mounted at / when its request " +
		"has the root_dispatcher option set to 'no'" do
		request = mock( "request object", :null_object => true )
		request.should_receive( :options ).at_least(:once).
			and_return({ 'root_dispatcher' => 'no' })
		txn = Arrow::Transaction.new( request, nil, nil )
		
		txn.root_dispatcher?.should be_false()
	end

	it "knows it's not dispatched from a handler mounted at / when its request " +
		"has the root_dispatcher option set to '0'" do
		request = mock( "request object", :null_object => true )
		request.should_receive( :options ).at_least(:once).
			and_return({ 'root_dispatcher' => '0' })
		txn = Arrow::Transaction.new( request, nil, nil )
		
		txn.root_dispatcher?.should be_false()
	end
end


describe Arrow::Transaction, " (an instance)" do

	before(:each) do
		@mockrequest = mock( "request object", :null_object => true )
		@txn = Arrow::Transaction.new( @mockrequest, nil, nil )
	end

	
	it "knows that a form was submitted if there's a urlencoded form content-type header with a POST" do
		headers = Apache::Table.new({'content-type' => 'application/x-www-form-urlencoded'})
		@mockrequest.should_receive( :headers_in ).
			at_least(1).
			and_return( headers )
		@mockrequest.should_receive( :request_method ).
			at_least(1).
			and_return('POST')
		@txn.should be_a_form_request
	end

	it "knows that a form was submitted if there's a urlencoded form content-type header with a PUT" do
		headers = Apache::Table.new({'content-type' => 'application/x-www-form-urlencoded'})
		@mockrequest.should_receive( :unparsed_uri ).
			at_least(1).
			and_return( '' )# query is nil
		@mockrequest.should_receive( :headers_in ).
			at_least(1).
			and_return( headers )
		@mockrequest.should_receive( :request_method ).
			at_least(1).
			and_return('PUT')
		@txn.should be_a_form_request
	end

	it "knows that a form was submitted if there's a urlencoded form content-type header with a GET" do
		@mockrequest.should_receive( :unparsed_uri ).
			at_least(1).
			and_return( 'foo?bar=bas&biz=boz' )
		@mockrequest.should_receive( :request_method ).
			at_least(1).
			and_return('GET')
		@txn.should be_a_form_request
	end

	it "knows that a form was submitted if there's a urlencoded form content-type header with a DELETE" do
		@mockrequest.should_receive( :unparsed_uri ).
			at_least(1).
			and_return( 'foo?bar=bas&biz=boz' )
		@mockrequest.should_receive( :request_method ).
			at_least(1).
			and_return('DELETE')
		@txn.should be_a_form_request
	end


	it "should indicate a successful response when the status is 200" do
		@mockrequest.should_receive( :status ).
			at_least(:once).
			and_return( Apache::HTTP_OK )
		@txn.is_success?.should be_true
	end

	it "should indicate a successful response when the status is 201" do
		@mockrequest.should_receive( :status ).
			at_least(:once).
			and_return( Apache::HTTP_CREATED )
		@txn.is_success?.should be_true
	end

	it "should indicate a successful response when the status is 202" do
		@mockrequest.should_receive( :status ).
			at_least(:once).
			and_return( Apache::HTTP_ACCEPTED )
		@txn.is_success?.should be_true
	end

	it "should indicate a non-successful response when the status is 302" do
		@mockrequest.should_receive( :status ).
			at_least(:once).
			and_return( Apache::HTTP_MOVED_TEMPORARILY )
		@txn.is_success?.should_not be_true
	end

	it "should set its Apache status to REDIRECT when #redirect is called" do
		@mockrequest.should_receive( :status= ).with( Apache::HTTP_MOVED_TEMPORARILY )
		@txn.redirect( 'http://example.com/something' )
		@txn.handler_status.should == Apache::REDIRECT
	end

	it "delegates to the request for request methods" do
		@mockrequest.should_receive( :allowed ).and_return( :yep )
		@txn.allowed.should == :yep
	end


	it "returns the X-Forwarded-Host header if present for the value returned by #proxied_host" do
		headers = Apache::Table.new({
			'X-Forwarded-Host' => 'foo.bar.com',
		})

		@mockrequest.should_receive( :headers_in ).and_return( headers )
		@txn.proxied_host.should == 'foo.bar.com'
	end
	
	it "returns the X-Forwarded-Server header if X-Forwarded-Host is not " +
		"present for the value returned by #proxied_host" do
		headers = Apache::Table.new({
			'X-Forwarded-Server' => 'foo.bar.com',
		})

		@mockrequest.should_receive( :headers_in ).and_return( headers )
		@txn.proxied_host.should == 'foo.bar.com'
	end


	it "uses the proxy header for #construct_url" do
		headers = Apache::Table.new({
			'X-Forwarded-Host' => 'foo.bar.com',
			'X-Forwarded-Server' => 'foo.bar.com',
		})

		@mockrequest.should_receive( :headers_in ).
			and_return( headers )
		@mockrequest.should_receive( :construct_url ).
			and_return( 'http://hostname/bar' )

		@txn.construct_url( "/bar" ).should == 'http://foo.bar.com/bar'
	end

	it "knows when the transaction is requested via XHR by the X-Requested-With header" do
		headers = Apache::Table.new({
			'X-Requested-With' => 'XMLHttpRequest',
		})
		
		@mockrequest.should_receive( :headers_in ).and_return( headers )
		@txn.is_ajax_request?.should be_true()
	end
	
	
	it "knows when the transaction is not requested via XHR by the absence " +
		"of an X-Requested-With header" do
		headers = Apache::Table.new({})
		
		@mockrequest.should_receive( :headers_in ).and_return( headers )
		@txn.is_ajax_request?.should be_false()
	end
	
	it "knows when the transaction is not requested via XHR by a non-AJAX " +
		"X-Requested-With header" do
		headers = Apache::Table.new({
			'X-Requested-With' => 'magic jellybeans of doom',
		})
		
		@mockrequest.should_receive( :headers_in ).and_return( headers )
		@txn.is_ajax_request?.should be_false()
	end
	

	it "returns cookies from its headers as an Arrow::CookieSet" do
		headers = Apache::Table.new({
			'Cookie' => 'foo=12',
		})
		
		@mockrequest.should_receive( :headers_in ).and_return( headers )

		# Cookies are parsed on transaction creation, so we can't use the
		# transaction that's created in the before(:each)
		txn = Arrow::Transaction.new( @mockrequest, nil, nil )

		txn.request_cookies.should be_an_instance_of( Arrow::CookieSet )
		txn.request_cookies.should include( 'foo' )
		txn.request_cookies['foo'].should be_an_instance_of( Arrow::Cookie )
	end

	it "adds Cookie headers for each cookie in a successful response" do
		output_headers = mock( "output headers", :null_object => true )
		@mockrequest.should_receive( :headers_out ).
			at_least(:once).
			and_return( output_headers )
		@mockrequest.should_receive( :status ).
			at_least(:once).
			and_return( Apache::HTTP_OK )
		
		output_headers.should_receive( :[]= ).with( 'Set-Cookie', /glah=locke/i ) 
		output_headers.should_receive( :[]= ).with( 'Set-Cookie', /foo=bar/i ) 
		output_headers.should_receive( :[]= ).with( 'Set-Cookie', /pants=velcro/i )

		@txn.cookies['glah'] = 'locke'
		@txn.cookies['foo'] = 'bar'
		@txn.cookies['pants'] = 'velcro!'
		@txn.cookies['pants'].expires = 'Sat Nov 12 22:04:00 1955'
		
		@txn.add_cookie_headers
	end
	
	it "adds Cookie error headers for each cookie in an non-OK response" do
		output_headers = mock( "output headers", :null_object => true )
		err_output_headers = mock( "error output headers", :null_object => true )
		@mockrequest.should_not_receive( :headers_out )
		@mockrequest.should_receive( :err_headers_out ).
			at_least(:once).
			and_return( err_output_headers )
		@mockrequest.should_receive( :status ).
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
	
end


describe Arrow::Transaction, " dispatched from a root dispatcher" do
	
	before(:each) do
		@mockrequest = mock( "request object", :null_object => true )
		@mockrequest.stub!( :options ).and_return({ "root_dispatcher" => 'yes' })
		@txn = Arrow::Transaction.new( @mockrequest, nil, nil )
	end

	it "returns an empty string for the approot" do
		@txn.app_root.should == ''
	end

end


# vim: set nosta noet ts=4 sw=4:
