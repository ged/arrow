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
	testsdir = File::dirname( File::expand_path(__FILE__) )
	basedir = File::dirname( testsdir )
	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/tests/lib" unless
		$LOAD_PATH.include?( "#{basedir}/tests/lib" )

	require 'arrowtestcase'
end

require 'arrow/session'
require 'arrow/config'
require 'arrow/transaction'


# :TODO: This should really be a whole suite of mock objects for mod_ruby
# testing, but I'm lazy.

# Mock Apache::Request class
module Apache
	class Cookie
		def initialize( name, value=nil )
			@name = name
			@value = value
		end
		
		attr_accessor :name, :value
	end # class Cookie

	class Request
		def initialize( params={}, cookies={} )
			@params = params
			@cookies = Hash::new
			cookies.each {|k,v| @cookies[k] = Cookie::new(k,v)}
		end
		
		attr_reader :cookies
		attr_reader :params

		def param( key )
			@params[key]
		end
	end # class Request
end


# Mock Arrow::Transaction class
class MockTransaction < Test::Unit::MockObject( Arrow::Transaction )
	def initialize( req )
		@request = req
		super
	end
	attr_reader :request
end


### Collection of tests for the Arrow::Session class.
class Arrow::SessionTestCase < Arrow::TestCase

	### Configuration
	SessionDir			= File::dirname( File::expand_path(__FILE__) ) + "/sessions"

	DefaultIdUri		= "md5:."
	DefaultIdType		= 'Arrow::Session::MD5Id'
	DefaultLockUri		= "file:#{SessionDir}"
	DefaultLockType		= 'Arrow::Session::FileLock'
	DefaultStoreUri		= "file:#{SessionDir}"
	DefaultStoreType	= 'Arrow::Session::YamlStore'

	DefaultConfigHash = {
		:idType		=> DefaultIdUri,
		:lockType	=> DefaultLockUri,
		:storeType	=> DefaultStoreUri,
	}


	### Set up each test
	def setup
		@req = Apache::Request::new
		@txn = MockTransaction::new( @req )
		super
	end

	### Clean up after each test
	def teardown
		super
		@txn = nil
		@req = nil
	end


	#################################################################
	###	T E S T S
	#################################################################

	### Test to be sure component classes are loaded.
	def test_00_Classes
		printTestHeader "Session: Component classes"

		assert_block( "Arrow::Session defined?" ) { defined? Arrow::Session }
		assert_instance_of Class, Arrow::Session
	end


	### Test Session configuration
	def test_10_FactoryMethod
		printTestHeader "Session: Configure"
		rval = nil
		config = Arrow::Config::new

		assert_nothing_raised {
			Arrow::Session::configure( config )
		}

		assert_nothing_raised {
			rval = Arrow::Session::create( @txn, DefaultConfigHash )
		}
		assert_instance_of Arrow::Session, rval
	end

end

