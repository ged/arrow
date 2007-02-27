#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Transaction class
# $Id: TEMPLATE.rb.tpl,v 1.3 2003/09/17 22:30:08 deveiant Exp $
#
# Copyright (c) 2006 RubyCrafters, LLC. Most rights reserved.
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

### Collection of tests for the Arrow::Transaction class.
class Arrow::TransactionTestCase < Arrow::TestCase


	#################################################################
	###	T E S T S
	#################################################################

	def test_transaction_delegates_to_request_for_request_methods
		allowed = Apache::M_GET|Apache::M_POST
		
		with_fixtured_request do |txn, req, config, broker|
			req.should_receive( :allowed ).and_return( allowed ).once
			assert_equal allowed, txn.allowed
		end
	end


	def test_approot_with_root_dispatcher_should_return_empty_string
		rval = ''
		
		with_fixtured_request( "/", 'root_dispatcher' => "true" ) do |txn, req, config, broker|
			rval = txn.app_root
		end
		
		assert_equal "", rval,
			"#app_root should return an empty string for a base URI"
	end


	def test_root_dispatcher_option_in_options_should_set_up_root_dispatched_transaction
		rval = ''
		
		with_fixtured_request( "/", 'root_dispatcher' => "true" ) do |txn, req, config, broker|
			rval = txn.root_dispatcher?
		end
		
		assert_equal true, rval, "root_dispatcher? should be true"
	end


	def test_root_dispatcher_option_false_in_options_should_not_set_up_root_dispatched_transaction
		rval = ''
		
		with_fixtured_request( "/", 'root_dispatcher' => "false" ) do |txn, req, config, broker|
			rval = txn.root_dispatcher?
		end
		
		assert_equal false, rval, "root_dispatcher? should be false"
	end


	def test_root_dispatcher_option_no_in_options_should_not_set_up_root_dispatched_transaction
		rval = ''
		
		with_fixtured_request( "/", 'root_dispatcher' => "no" ) do |txn, req, config, broker|
			rval = txn.root_dispatcher?
		end
		
		assert_equal false, rval, "root_dispatcher? should be false"
	end


	def test_root_dispatcher_option_0_in_options_should_not_set_up_root_dispatched_transaction
		rval = ''
		
		with_fixtured_request( "/", 'root_dispatcher' => "" ) do |txn, req, config, broker|
			rval = txn.root_dispatcher?
		end
		
		assert_equal false, rval, "root_dispatcher? should be false"
	end


	# Simulate Apache::Table
	class HeaderTable
		def initialize( hash={} )
			hash.each {|k,v| hash[k.downcase] = v}
			@hash = hash
		end
		
		def []( key )
			@hash[ key.downcase ]
		end
		
		def []=( key, val )
			@hash[ key.downcase ] = val
		end
		
		def key?( key )
			@hash.key?( key.downcase )
		end
	end


	def test_proxied_host_should_return_x_forwarded_host_if_present
		rval = ''
		headers = HeaderTable.new({
			'X-Forwarded-Host' => 'foo.bar.com',
			'X-Forwarded-Server' => 'bar.foo.com',
		})
		
		FlexMock.use( "request", "config", "broker" ) do |req, config, broker|
			req.should_receive( :hostname ).
				and_return( "hostname" ).once
			req.should_receive( :options ).
				and_return( {} ).at_least.once
			req.should_receive( :headers_in ).
				and_return( headers ).
				at_least.once

			txn = Arrow::Transaction.new( req, config, broker )
			rval = txn.proxied_host
		end
		
		assert_equal 'foo.bar.com', rval
	end
	

	def test_proxied_host_should_return_x_forwarded_server_if_x_forwarded_host_not_present
		rval = ''
		headers = HeaderTable.new({
			'X-Forwarded-Server' => 'bar.foo.com',
		})
		FlexMock.use( "request", "config", "broker" ) do |req, config, broker|
			req.should_receive( :hostname ).
				and_return( "hostname" ).once
			req.should_receive( :options ).
				and_return( {} ).
				and_return(headers).
				at_least.once
				req.should_receive( :headers_in ).
					and_return( headers ).
					at_least.once

			txn = Arrow::Transaction.new( req, config, broker )
			rval = txn.proxied_host
		end
		
		assert_equal 'bar.foo.com', rval
	end
	

	def test_construct_url_with_x_forwarded_host_uses_proxy_header
		rval = ''
		headers = HeaderTable.new({
			'X-Forwarded-Host' => 'foo.bar.com',
			'X-Forwarded-Server' => 'bar.foo.com',
		})
		
		FlexMock.use( "request", "config", "broker" ) do |req, config, broker|
			req.should_receive( :hostname ).
				and_return( "hostname" ).once
			req.should_receive( :options ).
				and_return( {} ).at_least.once
			req.should_receive( :headers_in ).
				and_return( headers ).
				at_least.once
			req.should_receive( :construct_url ).
				with( "/bar" ).
				and_return( "http://hostname/bar").once
			
			txn = Arrow::Transaction.new( req, config, broker )
			rval = txn.construct_url( "/bar" )
		end
		
		assert_equal 'http://foo.bar.com/bar', rval
	end


	def test_ajax_request_returns_true_when_requested_with_header_is_xmlhttprequest
		rval = ''
		headers = HeaderTable.new({
			'X-Requested-With' => 'XMLHttpRequest',
		})
		
		FlexMock.use( "request", "config", "broker" ) do |req, config, broker|
			req.should_receive( :hostname ).
				and_return( "hostname" ).once
			req.should_receive( :options ).
				and_return( {} ).at_least.once
			req.should_receive( :headers_in ).
				and_return( headers ).
				at_least.once
			
			txn = Arrow::Transaction.new( req, config, broker )
			rval = txn.is_ajax_request?
		end
		
		assert_equal true, rval
	end

	def test_ajax_request_returns_false_when_requested_with_header_is_missing
		rval = ''
		headers = HeaderTable.new({
		})
		
		FlexMock.use( "request", "config", "broker" ) do |req, config, broker|
			req.should_receive( :hostname ).
				and_return( "hostname" ).once
			req.should_receive( :options ).
				and_return( {} ).at_least.once
			req.should_receive( :headers_in ).
				and_return( headers ).
				at_least.once
			
			txn = Arrow::Transaction.new( req, config, broker )
			rval = txn.is_ajax_request?
		end
		
		assert_equal false, rval
	end

	def test_ajax_request_returns_false_when_requested_with_header_is_not_xmlhttprequest
		rval = ''
		headers = HeaderTable.new({
			'X-Requested-With' => 'magic jellybeans of doom',
		})
		
		FlexMock.use( "request", "config", "broker" ) do |req, config, broker|
			req.should_receive( :hostname ).
				and_return( "hostname" ).once
			req.should_receive( :options ).
				and_return( {} ).at_least.once
			req.should_receive( :headers_in ).
				and_return( headers ).
				at_least.once
			
			txn = Arrow::Transaction.new( req, config, broker )
			rval = txn.is_ajax_request?
		end
		
		assert_equal false, rval
	end


	def test_transaction_cookies_should_return_a_cookieset_parsed_from_the_request
		headers = HeaderTable.new({
			'Cookie' => 'foo=12',
		})
		rval = nil

		FlexMock.use( "request", "config", "broker" ) do |req, config, broker|
			req.should_receive( :hostname ).and_return( "hostname" ).once
			req.should_receive( :options ).and_return( {} ).at_least.once
			req.should_receive( :headers_in ).and_return( headers ).at_least.once
			
			txn = Arrow::Transaction.new( req, config, broker )
			rval = txn.cookies
		end
		
		assert_instance_of Arrow::CookieSet, rval
		assert_instance_of Arrow::Cookie, rval['foo']
		assert_equal '12', rval['foo'].value
	end


	def test_transaction_should_add_cookie_headers_to_its_response_for_each_cookie
		headers = HeaderTable.new({})
		headers_out = HeaderTable.new({})
		
		cookie_pattern = /((glah=locke|foo=bar|pants=velcro!).*){3}/
		
		FlexMock.use( "request", "config", "broker", "outheaders" ) do |req, config, broker, outhdrs|
			req.should_receive( :hostname ).and_return( "hostname" ).once
			req.should_receive( :options ).and_return( {} ).at_least.once
			req.should_receive( :headers_in ).and_return( headers ).at_least.once
			
			req.should_receive( :headers_out ).and_return( outhdrs )
			outhdrs.should_receive( :[]= ).with( 'Set-Cookie', cookie_pattern ) 
			
			txn = Arrow::Transaction.new( req, config, broker )
			txn.cookies['glah'] = 'locke'
			txn.cookies['foo'] = 'bar'
			txn.cookies['pants'] = 'velcro!'
			txn.cookies['pants'].expires = "Sat Nov 12 22:04:00 1955"

			txn.add_cookie_headers
		end
	end
	

	#######
	private
	#######

	### Set up mocks for the request, config, and broker and yield them to
	### the given block.
	def with_fixtured_request( uri="/", options={} )
		debugMsg "Request uri = %p, options = %p" % [ uri, options ]
		
		FlexMock.use( "request", "config", "broker" ) do |req, config, broker|
			req.should_receive( :hostname ).
				and_return( "hostname" ).once
			req.should_receive( :options ).
				and_return( options ).at_least.once
			req.should_receive( :headers_in ).
				and_return({}).at_least.once

			txn = Arrow::Transaction.new( req, config, broker )
			
			yield( txn, req, config, broker )
		end
	end
	
end
