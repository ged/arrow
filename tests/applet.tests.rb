#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Applet class
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

	require 'arrow/testcase'
end


### Collection of tests for the Arrow::Applet class.
class Arrow::Applet::TestCase < Arrow::TestCase


    def setup
        @appletclass = Class.new( Arrow::Applet ) {
			applet_maintainer "ged@FaerieMUD.org"
			default_action :test
	
			def test_action( txn, *args )
				if defined? @action_body
					@action_body.call( txn, *args )
				end
			end

			def def_action_body( &block )
				@action_body = block
			end
		}
		@appletclass.filename = __FILE__
		@applet = @appletclass.new( nil, nil, nil )

		@appletsubclass = Class.new( @appletclass )
		@subapplet = @appletsubclass.new( nil, nil, nil )
    end


    def teardown
        Arrow::Applet.newly_loaded.clear
        Arrow::Applet.derivatives.clear
    end


	#################################################################
	###	T E S T S
	#################################################################

    def test_applet_subclass_should_have_signature_even_without_defining_one
        sig = nil
        assert_nothing_raised do
            sig = @appletclass.signature
        end
        
        assert_instance_of Arrow::Applet::SignatureStruct, sig
        assert_include "name", sig.members, "Struct members"
    end


	### Signature inheritance
	def test_applet_subsubclass_should_inherit_its_parents_signature
		sig = nil
		
		assert_nothing_raised do
			sig = @appletsubclass.signature
		end
		
		assert_instance_of Arrow::Applet::SignatureStruct, sig
		assert_equal "ged@FaerieMUD.org", sig.maintainer
		assert_not_same @appletclass.signature.maintainer,
			@appletsubclass.signature.maintainer
	end

	def test_action_function_should_install_an_action_method
		rval = meow = nil

		# Definition only
		assert_nothing_raised do
			@appletclass.instance_eval do
				def_action( "woof" ) { "woof" }
			end
		end
		assert_has_instance_method @appletclass, :woof_action

		# With Proxy
		assert_nothing_raised do
			@appletclass.instance_eval do
				meow = def_action("meow") {"meow"}
				meow.template = 'one.tmpl'
			end
		end
		assert_instance_of Arrow::Applet::SigProxy, meow
		assert_has_instance_method @appletclass, :meow_action
		assert_include :meow, @appletclass.signature[:templates].keys,
		    "signature entries missing"
		assert_equal 'one.tmpl', @appletclass.signature[:templates][:meow]
	end
	
	
	def test_action_function_should_accept_a_symbol_too
		rval = meow = nil

		# Definition only
		assert_nothing_raised do
			@appletclass.instance_eval do
				def_action :woof do
					"woof"
				end
			end
		end
		assert_has_instance_method @appletclass, :woof_action

		# With Proxy
		assert_nothing_raised do
			@appletclass.instance_eval do
				meow = def_action :meow do
					"meow"
				end
				meow.template = 'one.tmpl'
			end
		end
		assert_instance_of Arrow::Applet::SigProxy, meow
		assert_has_instance_method @appletclass, :meow_action
		assert_include :meow, @appletclass.signature[:templates].keys,
		    "signature entries missing"
		assert_equal 'one.tmpl', @appletclass.signature[:templates][:meow]
	end
	
	
	def test_load_template_should_delegate_to_the_designated_template_factory
		rval = nil

		FlexMock.use( "factory" ) do |factory|
			factory.should_receive( :get_template ).with( 'glah/luh.tmpl' ).and_return( "passed" )
			
			@appletclass.signature.templates[:foo] = 'glah/luh.tmpl'
			applet = @appletclass.new( nil, factory, nil )
			rval = applet.__send__( :load_template, :foo )
		end
		
		assert_equal "passed", rval
	end


	def test_load_template_should_raise_an_error_for_templates_not_in_the_signature
		assert_raises( Arrow::AppletError ) do
			applet = @appletclass.new( nil, nil, nil )
			applet.__send__( :load_template, :foo )
		end
	end


	def test_template_directive_should_add_a_template_to_the_signature
		assert !@appletclass.signature.templates.key?( :foo )

		assert_nothing_raised do
			@appletclass.class_eval do
				template :foo, "foo.tmpl"
			end
		end
		
		assert_equal "foo.tmpl", @appletclass.signature.templates[:foo]
	end

	def test_template_directive_should_accept_single_hash_pair
		assert !@appletclass.signature.templates.key?( :foo )

		assert_nothing_raised do
			@appletclass.class_eval do
				template :foo => "foo.tmpl"
			end
		end
		
		assert_equal "foo.tmpl", @appletclass.signature.templates[:foo]
	end

	def test_template_directive_should_accept_multiple_hash_pairs
		assert !@appletclass.signature.templates.key?( :foo )
		assert !@appletclass.signature.templates.key?( :bar )

		assert_nothing_raised do
			@appletclass.class_eval do
				template :foo => "foo.tmpl",
					:bar => "bar.tmpl"
			end
		end
		
		assert_equal "foo.tmpl", @appletclass.signature.templates[:foo]
		assert_equal "bar.tmpl", @appletclass.signature.templates[:bar]
	end

	def test_applet_name_directive_should_set_signature_name
		assert_not_equal "foo", @appletclass.signature.name

		assert_nothing_raised do
			@appletclass.class_eval do
				applet_name "foo"
			end
		end
		
		assert_equal "foo", @appletclass.signature.name
	end

	def test_applet_description_directive_should_set_signature_description
		assert_not_equal "foo", @appletclass.signature.description

		assert_nothing_raised do
			@appletclass.class_eval do
				applet_description "foo"
			end
		end
		
		assert_equal "foo", @appletclass.signature.description
	end

	def test_applet_maintainer_directive_should_set_signature_maintainer
		assert_not_equal "foo", @appletclass.signature.maintainer

		assert_nothing_raised do
			@appletclass.class_eval do
				applet_maintainer "foo"
			end
		end
		
		assert_equal "foo", @appletclass.signature.maintainer
	end

	def test_applet_appicon_directive_should_set_signature_appicon
		assert_not_equal "foo.png", @appletclass.signature.appicon

		assert_nothing_raised do
			@appletclass.class_eval do
				applet_maintainer "foo.png"
			end
		end
		
		assert_equal "foo.png", @appletclass.signature.maintainer
	end

	def test_applet_version_directive_should_set_signature_version
		assert_not_equal "200.1", @appletclass.signature.version

		assert_nothing_raised do
			@appletclass.class_eval do
				applet_version "200.1"
			end
		end
		
		assert_equal "200.1", @appletclass.signature.version
	end

	def test_default_action_directive_should_set_signature_default_action
		assert_not_equal :edit, @appletclass.signature.default_action

		assert_nothing_raised do
			@appletclass.class_eval do
				default_action :edit
			end
		end
		
		assert_equal "edit", @appletclass.signature.default_action
	end


	def test_run_should_track_run_times
		assert_equal 0.0, @applet.total_utime
		assert_equal 0.0, @applet.total_stime
		
		@applet.def_action_body do |txn|
			# This will hopefully take more than 0.0 seconds on any machine.
			10_000.times do
				a = Array.new(200, "A")
				a.sort
			end
		end

		with_run_fixtured_transaction do |txn|
			@applet.run( txn, "test" )
		end

		assert (@applet.total_utime > 0.0), 
			"Applet utime after run: %0.5f" % [@applet.total_utime]
		assert (@applet.total_stime > 0.0), 
			"Applet stime after run: %0.5f" % [@applet.total_stime]
	end

	
	def test_defining_an_action_method_with_inappropriate_arity_should_raise_scripterror
		assert_raises( ScriptError ) do
			@appletclass.class_eval { def malformed_action; end }
		end
	end


	def test_running_against_action_method_with_inappropriate_arity_should_raise_appleterror
		# We have to sneak a method past the ::method_added check...
		@appletclass.class_eval do
			def self::method_added(sym); end
			def malformed_action; end
		end

		assert_raises( Arrow::AppletError ) do
			with_run_fixtured_transaction do |txn|
				@applet.run( txn, "malformed" )
			end
		end
	end	


	def test_run_with_two_arg_action_sends_the_appropriate_number_of_args
		@appletclass.class_eval do
			def two_arg_action( txn, arg )
				[ txn, arg ]
			end
		end
		@applet = @appletclass.new( nil, nil, nil )

		with_run_fixtured_transaction do |txn|
			rval = @applet.run( txn, "two_arg", "arg1", "arg2", "arg3" )

			assert_instance_of Array, rval
			assert_equal 2, rval.length
			assert_same txn, rval.first
			assert_equal "arg1", rval[1]
		end

	end


	def test_run_with_block_yields_action_method_and_transaction_instead_of_invoking
		rval, meth, rtxn, rargs = nil

		with_run_fixtured_transaction do |txn|
			rval = @applet.run( txn, "test", "arg1", "arg2" ) do |metharg, txn2, *args|
				meth = metharg
				rtxn = txn2
				rargs = args

				:passed
			end

			assert_instance_of Method, meth
			assert_match( /#test_action/, meth.to_s )
			assert_same txn, rtxn
			assert_equal ["arg1", "arg2"], rargs

			assert_equal :passed, rval
		end
	end


	def test_run_with_parameterless_action_method_raises_an_appleterror
		@applet.def_action_body do
			flunk "Expected exception before action body was run"
		end

		with_run_fixtured_transaction do |txn|
			assert_raises( Arrow::AppletError ) do
				@applet.run( txn, "malformed" )
			end
		end
	end


	def test_run_without_an_action_invokes_the_default_action
		invoked = false

		@applet.def_action_body do
			invoked = true
		end

		with_run_fixtured_transaction do |txn|
			rval = @applet.run( txn )
		end

		assert_equal true, invoked, "Default action was not invoked"
	end


	def test_looking_up_a_valid_action_method_should_return_method_object_for_it
		rval = nil
		args = []

		assert_nothing_raised do
			rval, *args = @applet.lookup_action_method( "test" )
		end

		assert_instance_of Method, rval
		assert_match( /#test_action/, rval.to_s )
	end


	def test_lookup_of_invalid_action_returns_action_missing_action_and_adds_an_arg
		rval = nil
		args = []

		assert_nothing_raised do
			rval, *args = @applet.lookup_action_method( 'pass' )
		end

		assert_instance_of Method, rval
		assert_equal 1, args.length, "args: %p" % [args]
		assert_equal "pass", args.first
		assert_match( /#action_missing_action/, rval.to_s )
	
	end


	def test_default_delegation_method_just_yields
		rval = nil

		assert_nothing_raised do
			rval = @applet.delegate( nil, [:chain] ) {|arg| rval = arg }
		end

		assert_equal [:chain], rval
	end


	def test_subrun_from_delegation_populates_txn_vargs
		
		# Define the delegator and an action to subrun
		@appletclass.class_eval do
			def delegate( txn, chain, *args )
				self.subrun( :test_vargs, txn, *args )
			end
			def test_vargs_action( txn, *args )
			end
		end
		
		applet = @appletclass.new( nil, nil, nil )
		
		# Even though it's not a real #run, the transaction should be
		# set up the same way passing through #subrun
		with_run_fixtured_transaction do |txn, req|
			txn.should_receive( :vargs ).and_return(nil).at_least.once

			assert_nothing_raised do
				applet.delegate( txn, nil )
			end
		end

	end


	#######
	private
	#######


	def with_run_fixtured_transaction
		FlexMock.use( "transaction", "request" ) do |txn, req|
			txn.should_receive( :request ).and_return( req ).at_least.twice
			txn.should_receive( :vargs= ).once

			req.should_receive( :content_type= ).with( "text/html" ).once
			req.should_receive( :sync_header= ).with( true ).once
			req.should_receive( :paramtable ).and_return({}).once
			
			yield( txn )
		end
	end
end

