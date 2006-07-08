#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Session class
# $Id$
#
# Copyright (c) 2003 RubyCrafters, LLC. Most rights reserved.
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

require 'arrow/session'
require 'arrow/config'
require 'arrow/transaction'


### Collection of tests for the Arrow::Session class.
class Arrow::SessionTestCase < Arrow::TestCase

	### Configuration
	SessionDir			= File.dirname( File.expand_path(__FILE__) ) + "/sessions"

	DefaultIdUri		= "md5:."
	DefaultIdType		= 'Arrow::Session::MD5Id'
	DefaultLockUri		= "file:#{SessionDir}"
	DefaultLockType		= 'Arrow::Session::FileLock'
	DefaultStoreUri		= "file:#{SessionDir}"
	DefaultStoreType	= 'Arrow::Session::YamlStore'

    TestSessionId       = "6bfb3f041cf9204c3a2ea4611bd5c9d1"

	DefaultConfigHash = {
		:idType		=> DefaultIdUri,
		:idName     => "test_id",
		:lockType	=> DefaultLockUri,
		:storeType	=> DefaultStoreUri,
	}



	#################################################################
	###	T E S T S
	#################################################################

	def test_session_class_should_be_defined_and_be_a_class
		assert_block( "Arrow::Session defined?" ) { defined? Arrow::Session }
		assert_instance_of Class, Arrow::Session
	end


    def test_create_id_should_use_id_from_cookie_if_present
        rval = nil
        
        FlexMock.use( "config", "request", "cookie" ) do |config, request, cookie|
            request.should_receive( :cookies ).and_return({ "test_id" => cookie }).at_least.twice
            config.should_receive( :idName ).and_return( "test_id" ).at_least.twice
            cookie.should_receive( :value ).and_return( TestSessionId ).once
            config.should_receive( :idType ).and_return( DefaultIdUri )
            
            rval = Arrow::Session.create_id( config, request )
        end
        
        assert_kind_of Arrow::Session::Id, rval
        assert_equal TestSessionId, rval.to_s
    end        

end

