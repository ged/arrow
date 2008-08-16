#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'apache/fakerequest'
	require 'arrow'
	require 'arrow/session'
	require 'arrow/spechelpers'
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

describe Arrow::Session do

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

	TEST_CONFIG_HASH   = {
		:idType           => TEST_ID_URI,
		:idName           => TEST_ID_NAME,
		:lockType         => TEST_LOCK_URI,
		:storeType        => TEST_STORE_URI,
	}


	before( :each ) do
		@config = Arrow::Config.new
		@config.session = TEST_CONFIG_HASH
		pending "Completion"
	end
	

	it "uses the id contained in the configured session cookie if present when creating the id" do
		txn = mock( "transaction" )
		session_cookie = mock( "session cookie" )
		
		txn.should_receive( :request_cookies ).and_return({ TEST_ID_NAME => session_cookie })
		session_cookie.should_receive( :value ).and_return( TEST_SESSION_ID )
		
		Arrow::Session.create_id( @config, txn )
	end
	


	#################################################################
	###	T E S T S
	#################################################################

    def test_create_id_should_use_id_from_cookie_if_present
        rval = nil
        
        FlexMock.use( "config", "txn", "request", "cookie" ) do |config, txn, request, cookie|
            txn.should_receive( :request_cookies ).
				and_return({ "test_id" => cookie }).at_least.twice
            txn.should_receive( :request ).and_return( request )

            config.should_receive( :idName ).and_return( "test_id" ).at_least.once
            cookie.should_receive( :value ).and_return( TestSessionId ).once
            config.should_receive( :idType ).and_return( DefaultIdUri )
            
            rval = Arrow::Session.create_id( config, txn )
        end
        
        assert_kind_of Arrow::Session::Id, rval
        assert_equal TestSessionId, rval.to_s
    end        

	def test_the_session_class_should_know_what_the_session_cookie_name_is
		rval = nil
		
		FlexMock.use( "config" ) do |config|
			config.should_receive( :idName ).and_return( 'cookie-name' )
			Arrow::Session.configure( config )
			rval = Arrow::Session.session_cookie_name
		end
		
		assert_equal 'cookie-name', rval
	end

	def test_saving_should_add_the_session_cookie_to_the_request_via_the_transaction
		cookieset = Arrow::CookieSet.new
		config = Arrow::Config.new
		config.session.idName = 'cookie-name'
		Arrow::Session.configure( config.session )
		
		FlexMock.use( "config", "store", "txn", "lock" ) do |config, store, txn, lock|
			store.should_receive( :[]= ).with( :_session_id, 'id' )
			store.should_receive( :save )
			
			lock.should_receive( :release_all_locks )
			txn.should_receive( :cookies ).and_return( cookieset )
			
			session = Arrow::Session.new( :id, lock, store, txn )
			session.save
		end

		assert cookieset.include?( 'cookie-name' )
	end

end


# vim: set nosta noet ts=4 sw=4:
