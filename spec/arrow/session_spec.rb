#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rubygems'
require 'spec'
require 'apache/fakerequest'
require 'arrow'
require 'arrow/session'

require 'spec/lib/helpers'
require 'spec/lib/constants'


include Arrow::TestConstants


#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::Session do
	include Arrow::SpecHelpers

	### Configuration
	SESSION_DIR			= File.dirname( File.expand_path(__FILE__) ) + "/sessions"

	TEST_ID_URI        = "md5:."
	TEST_ID_NAME       = "test_id"
	TEST_ID_TYPE       = 'Arrow::Session::MD5Id'
	TEST_LOCK_URI      = "file:#{SESSION_DIR}"
	TEST_LOCK_TYPE     = 'Arrow::Session::FileLock'
	TEST_STORE_URI     = "file:#{SESSION_DIR}"
	TEST_STORE_TYPE    = 'Arrow::Session::YamlStore'

    TEST_SESSION_ID    = "6bfb3f041cf9204c3a2ea4611bd5c9d1"

	TEST_SESSION_CONFIG_HASH   = TEST_CONFIG_HASH.merge( :session => {
		:idType           => TEST_ID_URI,
		:idName           => TEST_ID_NAME,
		:lockType         => TEST_LOCK_URI,
		:storeType        => TEST_STORE_URI,
	})


	before( :all ) do
		setup_logging( :crit )
		@config = Arrow::Config.new( TEST_SESSION_CONFIG_HASH )
	end
	
	after( :all ) do
		reset_logging()
	end


	it "uses the id contained in the configured session cookie if present when creating the id" do
		txn = mock( "transaction" )
		request = stub( "request object" )
		txn.stub!( :request ).and_return( request )
		session_cookie = mock( "session cookie" )
		cookieset = mock( "arrow cookieset" )
		
		txn.should_receive( :request_cookies ).at_least( :once ).and_return( cookieset )
		cookieset.should_receive( :include? ).with( TEST_ID_NAME ).and_return( true )
		cookieset.should_receive( :[] ).with( TEST_ID_NAME ).and_return( session_cookie )
		session_cookie.should_receive( :value ).and_return( TEST_SESSION_ID )
		
		@config.session.idName.should == TEST_ID_NAME
		Arrow::Session.create_id( @config.session, txn )
	end
	
	
	it "knows what the session cookie name is after being configured" do
		Arrow::Session.configure( @config.session )
		Arrow::Session.session_cookie_name.should == TEST_ID_NAME
	end

	
	describe "instance" do

		before( :all ) do
			Arrow::Session.configure( @config.session )
		end
		
		
		before( :each ) do
			@cookieset = Arrow::CookieSet.new
			@config = Arrow::Config.new
			@config.session.idName = TEST_ID_NAME
			@txn = mock( "transaction" )
			@store = mock( "session store" )
			@lock = mock( "session lock" )

			Arrow::Session.configure( @config.session )

			@store.stub!( :[]= )
			@session = Arrow::Session.new( :id, @lock, @store, @txn )
		end
		
		
		it "adds the session cookie to the request when it is saved" do
			@lock.stub!( :release_all_locks )
			@txn.should_receive( :cookies ).and_return( @cookieset )

			@store.should_receive( :save )
			@session.save
		end
	
	end
	
end


# vim: set nosta noet ts=4 sw=4:
