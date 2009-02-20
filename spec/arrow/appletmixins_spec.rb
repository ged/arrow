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
require 'arrow/applet'
require 'arrow/appletmixins'


include Arrow::TestConstants

#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::AppletAuthentication do
	include Arrow::SpecHelpers,
	        Arrow::AppletMatchers

	before( :all ) do
		setup_logging( :crit )
	end

	after( :all ) do
		reset_logging()
	end


	before( :each ) do
		@uri = '/testing'
		@connection = stub( "apache connnection", :remote_host => 'host' )
		@txn = stub( "transaction", :uri => @uri, :vargs => true, :user => nil, 
			:authorized => false, :the_request => 'the request',
			:connection => @connection )
	end
	

	describe "included by an Applet" do

		describe " that doesn't override any of the auth methods" do
			before( :all ) do
				@appletclass = Class.new( Arrow::Applet ) do
					include Arrow::AppletAuthentication
				
					applet_name "Hi, I'm a fixture applet!"
				
					def initialize( *args )
						@authenticated = false
						@authorized = false
						super
					end

					attr_reader :authenticated, :authorized
				
					def authenticated_action( txn )
						with_authentication( txn ) do |user|
							@authenticated = true
						end
					end
				
					def authorized_action( txn )
						with_authorization( txn ) do
							@authorized = true
						end
					end
				end
			end
	
			before( :each ) do
				@applet = @appletclass.new( nil, nil, nil )
			end
	
			it "returns an UNAUTHORIZED response for an action wrapped in authentication" do
				@txn.should_receive( :status= ).with( Apache::HTTP_UNAUTHORIZED )
				@applet.authenticated_action( @txn ).should =~ /requires auth/i
				@applet.authenticated.should be_false()
			end
	
			it "returns an UNAUTHORIZED response for an action wrapped in authorization" do
				@txn.should_receive( :status= ).with( Apache::HTTP_UNAUTHORIZED )
				@applet.authorized_action( @txn ).should =~ /requires auth/i
				@applet.authorized.should be_false()
			end
	
		end

		describe " that provides an implementation of #get_authenticated_user" do
			before( :all ) do
				@appletclass = Class.new( Arrow::Applet ) do
					include Arrow::AppletAuthentication
				
					applet_name "Hi, I'm a fixture applet!"
				
					def initialize( *args )
						@authenticated = false
						@authorized = false
						super
					end

					attr_reader :authenticated, :authorized
				
					def authenticated_action( txn )
						with_authentication( txn ) do |user|
							@authenticated = true
						end
					end
				
					def authorized_action( txn )
						with_authorization( txn ) do
							@authorized = true
						end
					end
				
					def get_authenticated_user( txn )
						return txn.user
					end
				end
			end
	
			before( :each ) do
				@applet = @appletclass.new( nil, nil, nil )
			end
	
			it "returns an UNAUTHORIZED response for an action wrapped in authentication if " +
			   "the transaction doesn't contain a user" do
				@txn.should_receive( :status= ).with( Apache::HTTP_UNAUTHORIZED )
				@applet.authenticated_action( @txn ).should =~ /requires auth/i
				@applet.authenticated.should be_false()
			end
	
			it "returns a normal response for an action wrapped in authentication if " +
			   "the transaction does contain a user" do
				@txn.stub!( :user ).and_return( :barney_the_clown )
				@applet.authenticated_action( @txn ).should == true
				@applet.authenticated.should be_true()
			end
	
			it "returns an UNAUTHORIZED response for an action wrapped in authorization if " +
			   "the transaction doesn't contain a user" do
				@txn.should_receive( :status= ).with( Apache::HTTP_UNAUTHORIZED )
				@applet.authenticated_action( @txn ).should =~ /requires auth/i
				@applet.authorized.should be_false()
			end
	
			it "returns a FORBIDDEN response for an action wrapped in authorization if " +
			   "the transaction does contain a user" do
				@txn.stub!( :user ).and_return( :blinky_the_wombat )
				@txn.should_receive( :status= ).with( Apache::FORBIDDEN )
				@applet.authorized_action( @txn ).should =~ /access denied/i
				@applet.authorized.should be_false()
			end
	
		end

		describe " that also provides an implementation of #user_is_authorized" do
			before( :all ) do
				@appletclass = Class.new( Arrow::Applet ) do
					include Arrow::AppletAuthentication
				
					applet_name "Hi, I'm a fixture applet!"
				
					def initialize( *args )
						@authenticated = false
						@authorized = false
						super
					end

					attr_reader :authenticated, :authorized
				
					def authenticated_action( txn )
						with_authentication( txn ) do |user|
							@authenticated = true
						end
					end
				
					def authorized_action( txn )
						with_authorization( txn ) do
							@authorized = true
						end
					end
				
					def get_authenticated_user( txn )
						# Simplified for testing -- lets the test set whether or not authentication
						# exists
						return txn.user
					end

					def user_is_authorized( user, txn )
						# Simplified for testing -- lets the test set whether or not authorization
						# exists
						return txn.authorized
					end
				end
			end
	
			before( :each ) do
				@applet = @appletclass.new( nil, nil, nil )
			end
	
			it "returns an UNAUTHORIZED response for an action wrapped in authentication if " +
			   "the transaction doesn't contain a user" do
				@txn.should_receive( :status= ).with( Apache::HTTP_UNAUTHORIZED )
				@applet.authenticated_action( @txn ).should =~ /requires auth/i
				@applet.authenticated.should be_false()
				@applet.authorized.should be_false()
			end
	
			it "returns a FORBIDDEN response for an action wrapped in authentication if " +
			   "the transaction does contain a user" do
				@txn.stub!( :user ).and_return( :barney_the_clown )
				@applet.authenticated_action( @txn ).should == true
				@applet.authenticated.should be_true()
				@applet.authorized.should be_false()
			end
	
			it "returns an UNAUTHORIZED response for an action wrapped in authorization if " +
			   "the transaction doesn't contain a user" do
				@txn.should_receive( :status= ).with( Apache::HTTP_UNAUTHORIZED )
				@applet.authenticated_action( @txn ).should =~ /requires auth/i
				@applet.authorized.should be_false()
			end
	
			it "returns a FORBIDDEN response for an action wrapped in authorization if " +
			   "the transaction does contain a user, but the user isn't authorized" do
				@txn.stub!( :user ).and_return( :gurney_halleck )
				@txn.should_receive( :status= ).with( Apache::FORBIDDEN )
				@applet.authorized_action( @txn ).should =~ /access denied/i
				@applet.authorized.should be_false()
			end
	
			it "returns a normal response for an action wrapped in authorization if " +
			   "the transaction does contain a user, and the user is authorized" do
				@txn.stub!( :user ).and_return( :alia_atreides )
				@txn.stub!( :authorized ).and_return( true )
				@applet.authorized_action( @txn ).should == true
				@applet.authorized.should be_true()
			end
	
		end

	end

end

describe Arrow::AccessControls do
	include Arrow::SpecHelpers,
	        Arrow::AppletMatchers

	before( :all ) do
		setup_logging( :crit )
	end
	
	before( :each ) do
		@uri = '/testing'
	end

	after( :all ) do
		reset_logging()
	end


	it "adds a declarative method to including applet classes for adding to the list" +
	   " of methods which can be run without authentication" do
		@applet_class = Class.new( Arrow::Applet ) do
			include Arrow::AccessControls
		end
		
		@applet_class.respond_to?( :unauthenticated_actions )
		@applet_class.unauthenticated_actions.should have(3).members
		@applet_class.unauthenticated_actions.should include( :login, :logout, :deny_access )
	end
	

	describe "included in an Applet" do

		describe " that doesn't declare any other unauthenticated actions" do
			before( :all ) do
				@applet_class = Class.new( Arrow::Applet ) do
					include Arrow::AccessControls
					
					def action_missing_action( txn, action, *args )
						return action
					end
					
					def login_action( txn, *args )
						return :login
					end
					
					def logout_action( txn, *args )
						return :logout
					end
					
					def deny_access_action( txn, *args )
						return :deny_access
					end
				end
			end
		
			before( :each ) do
				@applet = @applet_class.new( nil, nil, @uri )
				@fakerequest = Apache::Request.new( @uri )
				@txn = Arrow::Transaction.new( @fakerequest, nil, nil )
			end
	
	
			it "doesn't require authentication for the :login action" do
				@applet.run( @txn, :login ).should == :login
			end
		
			it "doesn't require authentication for the :logout action" do
				@applet.run( @txn, :logout ).should == :logout
			end
			
			it "doesn't require authentication for the :deny_access action" do
				@applet.run( @txn, :deny_access ).should == :deny_access
			end
			
			it "requires authentication for any other action" do
				@applet.run( @txn, :serenity ).should == :login
			end
			
		end

		describe " that declares a custom unauthenticated action" do
			before( :all ) do
				@applet_class = Class.new( Arrow::Applet ) do
					include Arrow::AccessControls
					
					unauthenticated_actions :willy_nilly, :action_missing
					
					def action_missing_action( txn, action, *args )
						return :action_missing
					end
					
					def willy_nilly_action( txn, *args )
						return :willy_nilly
					end
					
					def serenity_action( txn, *args )
						return :serenity
					end
					
					def login_action( txn, *args )
						return :login
					end
					
					def logout_action( txn, *args )
						return :logout
					end
					
					def deny_access_action( txn, *args )
						return :deny_access
					end
				end
			end
		
			before( :each ) do
				@applet = @applet_class.new( nil, nil, @uri )
				@fakerequest = Apache::Request.new( @uri )
				@txn = Arrow::Transaction.new( @fakerequest, nil, nil )
			end
	
	
			it "doesn't require authentication for the :login action" do
				@applet.run( @txn, :login ).should == :login
			end
		
			it "doesn't require authentication for the :logout action" do
				@applet.run( @txn, :logout ).should == :logout
			end
			
			it "doesn't require authentication for the :deny_access action" do
				@applet.run( @txn, :deny_access ).should == :deny_access
			end
			
			it "doesn't require authentication for actions declared as unauthenticated" do
				@applet.run( @txn, :willy_nilly ).should == :willy_nilly
			end
			
			it "doesn't require authentication for remapped actions declared as unauthenticated" do
				@applet.run( @txn, :klang_locke ).should == :action_missing
			end
			
			it "requires authentication for any other action" do
				@applet.run( @txn, :serenity ).should == :login
			end
			
		end
	
	end


end # describe "Applet mixins"



