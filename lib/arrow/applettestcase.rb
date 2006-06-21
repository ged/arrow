#!/usr/bin/ruby
# 
# This is an abstract test case class for building Test::Unit unit tests for
# Arrow applets. 
# 
# == Synopsis
# 
#	$LOAD_PATH.unshift "tests/lib" unless $LOAD_PATH.include?("tests/lib")
#	require 'applettestcase'
#
#	class MySomethingTest < Arrow::AppletTestCase
#
#		applet_under_test "jobs"
#
#		def test_default_request_should_return_object_list
#			
#		end
#
#		def test_default_request_with_oid_arg_should_display_details
#			set_request_params :oid => 13
#		end
#
#	end
# 
# == Rcsid
# 
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Copyright (c) 2003, 2004, 2006 RubyCrafters, LLC.
# 
# This work is licensed under the Creative Commons Attribution License. To view
# a copy of this license, visit http://creativecommons.org/licenses/by/1.0 or
# send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California
# 94305, USA.
#
# 

unless defined? Arrow::TestCase
	testsdir = File.dirname( File.expand_path(__FILE__) )
	basedir = File.dirname( testsdir )
	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/tests/lib" unless
		$LOAD_PATH.include?( "#{basedir}/tests/lib" )
end

require 'apache/fakerequest'
require 'test/unit/assertions'
require 'test/unit/testcase'
require 'pathname'

require 'arrow'
require 'arrow/applet'


### Test case class
class Arrow::AppletTestCase < Test::Unit::TestCase
	include Test::Unit::Assertions, FlexMock::TestCase

	# The default path to the directory where applets live
	APPLET_PATH = Pathname.getwd + "applets"
	
	class << self
		attr_accessor :appletclass, :appletname, :fixture_data
	end


    ### Set up model +data+ for the given +model_class+ that can be used in 
    ### the stub data classes. The +data+ argument is an Array of data, and 
    ### can be either Hashes or Arrays. If Arrays are used, the first one in
    ### the list should be a list of fields, and each subsequent Array should
    ### be field values. E.g.,
    ###   [
    ###     [ :title, :description, :date ],
    ###     [ "title1", "desc1",    Date.today ],
    ###     [ "title2", "desc2",    Date.today-4 ],
    ###   ]
    ### which is equivalent to:
    ###   [
    ###     { :title => "title1", :description => "desc1", :date => Date.today }
    ###     { :title => "title1", :description => "desc1", :date => Date.today }
    ###   ]
    def self::set_fixture_data( model_class, data )
        @fixture_data ||= {}
        
		# [ [<fields>], [<values1], [<values2>] ]
        if data.first.is_a?( Array )
			fields = data.shift
			objects = data.collect do |row|
				obj = OpenStruct.new
				fields.each_with_index {|f,i| obj.__send__(f, row[i])}
			end

		# [ {:field1 => <value1>}, {:field1 => <value2>} ]
		elsif data.first.is_a?( Hash )
			objects = data.collect do |row|
				OpenStruct.new( row )
			end

		# Custom objects (Mocks, etc.)
		elsif data.is_a?( Array )
			objects = data
		end	
        
        @fixture_data[ model_class ] = objects
    end


	### Define the name of the applet under test. The given +name+ will be
	### stringified, downcased, and searched for in the #applet_path.
	def self::applet_under_test( applet )
		if applet.is_a?( Class )
			self.appletclass = applet
			self.appletname = applet.signature.name
		else
			debug_msg "Setting applet under test for testcase: %p" % [self]
		
			if Arrow::Applet.derivatives.empty?
	            Pathname.glob( APPLET_PATH + '**/*.rb' ).each do |appletfile|
	    		    debug_msg "Trying to load #{appletfile}"
	    		    Arrow::Applet.load( appletfile )
	    	    end
	        end

			self.appletclass = Arrow::Applet.derivatives.find {|klass|
				debug_msg "  Checking applet '#{klass.name.downcase}' =~ #{applet}..."
				klass.name.downcase[ applet.to_s ] # string-match
			} or raise "Failed to load applet '#{@appletname}' from #{applet}"
			self.appletname = applet.to_s

			debug_msg "Applet under test is: #{self.appletclass}"
		end
	end


    def initialize( *args )
        throw :invalid_test unless self.class.appletclass
        super
    end
        

	### Set up a test with some useful test objects
	def setup
		super

		debug_msg "%p: Setting up test for applet %p" % 
			[self.class, self.class.appletclass]

		# Give the test an easy reference to the applet class under test
		@appletclass = self.class.appletclass or
			raise "No applet defined for '#{self.class.name}'. Add " +
				"'applet_under_test :<appletname>' to correct this."
		@appletname = self.class.appletname
		@action = nil
		
		@config = flexmock( "mock config" )
		@config.should_receive( :symbolize_keys ).and_return({})
		@config.should_receive( :member? ).
			with( :db ).
			and_return( false )
		@config.should_receive( :name ).and_return( "mock" )
		@config.should_receive( :member? ).
			with( :model ).
			and_return( false )
		@template_factory = flexmock( "mock template factory" )

		@applet = @appletclass.new( @config, @template_factory, "/#{@appletname}" )
	
		@mock_dataclasses = Hash.new {|h,k|
			h[ k ] = flexmock( "#{k} data class" )
		}
		@applet.instance_variable_set( :@dataclasses, @mock_dataclasses )
		
		@delegate_behavior = nil
		@delegate_should_be_called = true
		@delegate_called = false
	end



	#################################################################
	###	T E S T   U T I L I T Y   M E T H O D S
	#################################################################

	### Access the applet's dataclasses
	attr_reader :mock_dataclasses
	alias_method :dataclasses, :mock_dataclasses


	### Set up faked request and transaction objects, yield to the given 
	### block with them, then run the applet under test with them when
	### the block returns.
	def with_fixtured_action( action=nil, *args )
		@action = action
		txn, req, *args = setup_fixtured_request( action, *args )
		yield( txn, req )
		return @applet.run( txn, action.to_s, *args )
	ensure
		@action = nil
	end
	
	
	### Set up a faked request and transaction object, yield to the given
	### block with them, and then call the #delegate method of the applet
	### under test. Unless otherwise indicated (via a call to 
	### #should_not_delegate), the expectation will be set up that the applet
	### under test should call its delegate.
	def with_fixtured_delegation( chain=[], *args )
		txn, req = setup_fixtured_request( "delegated_action", *args )

		# Set delegation expectation
		@delegate_behavior ||= should_delegate()

		yield( txn, req )
		
		rval = @applet.delegate( txn, chain, *args, &@delegate_behavior )
		
		if @delegate_should_be_called
			assert @delegate_called,
				"delegate applet was never called" 
		else
			assert !@delegate_called,
				"delegate applet was called unexpectedly"
		end

		return rval
	end


	### The default delegate block -- call this from within your 
	### #with_fixtured_delegation block if the applet under test should
	### delegate to the next applet in the chain.
	def should_delegate( &block )
		@delegate_should_be_called = true
		@delegate_behavior = block || 
			method( :default_delegation_behavior ).to_proc
	end


	### Negated delegate block -- call this at the end of your 
	### #with_fixtured_delegation block if the applet under test should *not* 
	### delegate to the next applet in the chain.
	def should_not_delegate( &block )
		@delegate_should_be_called = false
		@delegate_behavior = block || 
			method( :default_delegation_behavior ).to_proc
	end


	### The default block passed to Arrow::Applet#delegate by 
	### #with_fixtured_delegation if no block is passed to either 
	### #should_delegate or #should_not_delegate. If you override this, you
	### should either super to this method or set @delegate_called yourself.
	def default_delegation_behavior
		@delegate_called = true
	end
	

	### Set up faked request and transaction objects for the given +action+,
	### using the given +args+ as REST-style arguments, and/or query arguments
	### if the last element is a Hash.
	def setup_fixtured_request( action, *args )
		uri = '/' + File.join( @appletname, action.to_s )
		req = Apache::Request.new( uri )

		params = args.last.is_a?( Hash ) ? args.pop : {}
		debug_msg "Parameters hash set to: %p" % [params]
		req.paramtable = params

		debug_msg "Request is: %p" % [req]
		#txn = Arrow::Transaction.new( req, @config, nil )
		txn = flexmock( "transaction" )
		txn.should_receive( :request ).
		    and_return( req ).at_least.once
		txn.should_receive( :vargs= ).
		    with( Arrow::FormValidator ).at_least.once
		
		debug_msg "Transaction is: %p" % [txn]
		return txn, req, *args
	end


	### Assert that the current action should load the template associated with
	### the given +key+, and passes a mock template object to the given block
	### for further specification.
	def should_load_template( key )
		tname = @applet.signature.templates[ key ] or
			raise Test::Unit::AssertionFailedError.new(
				"Expected applet to load the '#{key.inspect}' template\n" +
				"but there was no such template registered by the application." )
		
		mock_template = flexmock( "'#{key.inspect}' template")
		@template_factory.should_receive( :get_template ).
			with( tname ).and_return( mock_template ).at_least.once

		yield( mock_template ) if block_given?
	end


	### Create a new mock object and register it to be verified at the end of 
	### the test.
	def create_mock( name )
        return flexmock( name )
	end


	### Set up a mock object as the given transaction's session.
	def fixture_session( txn )
		session = create_mock( "session" )
		#txn.instance_variable_set( :@session, session )
		txn.should_receive( :session ).
		    and_return( session ).at_least.once

		
		return session
	end


	def extract_parameters( queryhash, key=nil )
		profile = @applet.signature.validator_profiles[ @action ] ||
			@applet.signature_profiles[ :__default__ ]
		validator = Arrow::FormValidator.new( profile )
		
		validator.validate( queryhash )

		if key
			return validator.valid[ key ]
		else
			return validator.valid
		end
	end

end # class Arrow::AppletTestCase

