#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Broker class
# $Id$
#
# Copyright (c) 2004, 2006 RubyCrafters, LLC. Most rights reserved.
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

	require 'arrowtestcase'
end

require 'arrow/broker'
require 'arrow/utils'
require 'ostruct'


### Collection of tests for the Arrow::Broker class.
class Arrow::BrokerTestCase < Arrow::TestCase

	TestConfig = {
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

	def setup
		@conf = Arrow::Config.new( TestConfig )
		@broker = Arrow::Broker.new( @conf )
		super
	end

	def teardown
	    @broker = nil
		@conf = nil
		super
	end


	#################################################################
	###	T E S T S
	#################################################################

    def test_delegation_with_empty_path_to_root_mounted_dispatcher_invokes_root_applet
		res = nil

		with_run_fixtured_transaction( "" ) do |txn, req, applet|
			@broker.registry[""] = applet
			applet.should_receive( :run ).with( txn ).and_return( "PASSED" )

            assert_nothing_raised do
                res = @broker.delegate( txn )
            end
        end

		assert_equal "PASSED", res
    end


	def test_delegate_with_a_uri_that_maps_to_one_item_should_invoke_that_items_run_method
		rval = nil

		with_run_fixtured_transaction( "/admin/create/job/1" ) do |txn, req, applet|
			@broker.registry["admin"] = applet
			applet.should_receive( :run ).
				with( txn, "create", "job", "1" ).
				and_return( :passed ).once

			assert_nothing_raised do
				rval = @broker.delegate( txn )
			end
		end
		
		assert_equal :passed, rval
	end


### Not sure how to test with a mock that yields back to the caller, since
### FlexMock doesn't reconstruct the context of the call.
# 	def test_delegate_with_a_uri_that_maps_to_multiple_items_should_chain_applets_together
# 		rval = nil
# 		
# 		with_run_fixtured_transaction( "/admin/create/job/1" ) do |txn, req, applet|
# 			FlexMock.use( "root applet" ) do |chained_applet|
# 				sig = Arrow::Applet::SignatureStruct.new
# 				sig.name = "DelegatingApplet"
# 				chained_applet.should_receive( :signature ).
# 					and_return( sig ).once
# 				
# 				@broker.registry[""] = chained_applet
# 				@broker.registry["admin"] = applet
# 				
# 				link = [applet, "/admin", ["create", "job", "1"]]
# 				chained_applet.should_receive( :delegate ).
# # 					with( txn, [link], "admin", "create", "job", "1" ).
# 					and_return { yield }.
# 					once
# 				applet.should_receive( :run ).
# 					with( txn, "create", "job", "1" ).
# 					and_return( :passed ).
# 					once
# 			
# 				assert_nothing_raised do
# 					rval = @broker.delegate( txn )
# 				end
# 			end
# 		end
# 
# 		assert_equal :passed, rval
# 	end



	#######
	private
	#######

	def with_run_fixtured_transaction( uri, root=nil )
		unparsed_uri = [ root, uri ].compact.join("/")
		
		FlexMock.use( "transaction", "request", "applet" ) do |txn, req, applet|
			txn.should_receive( :path ).and_return( uri ).once
			txn.should_receive( :applet_path= ).at_least.once
			txn.should_receive( :unparsed_uri ).and_return( unparsed_uri ).once
			
			sig = Arrow::Applet::SignatureStruct.new
			sig.name = "MockApplet"
			applet.should_receive( :signature ).and_return( sig )

			yield( txn, req, applet )
		end
	end
end

