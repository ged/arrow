#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Transaction class
# $Id: TEMPLATE.rb.tpl,v 1.3 2003/09/17 22:30:08 deveiant Exp $
#
# Copyright (c) (>>>YEAR<<<) RubyCrafters, LLC. Most rights reserved.
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

### Collection of tests for the (>>>target<<<) class.
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


	#######
	private
	#######

	### Set up mocks for the request, config, and broker and yield them to
	### the given block.
	def with_fixtured_request( uri="/", options={} )
		debugMsg "Request uri = %p, options = %p" % [ uri, options ]
		
		FlexMock.use( "request", "config", "broker" ) do |req, config, broker|
			req.should_receive( :hostname ).and_return( "hostname" ).once
			req.should_receive( :options ).and_return( options ).at_least.once

			txn = Arrow::Transaction.new( req, config, broker )
			
			yield( txn, req, config, broker )
		end
	end
	
end
