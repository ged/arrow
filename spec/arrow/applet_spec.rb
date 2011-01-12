#!/usr/bin/env ruby
# 
# Specification for the Arrow::Applet class
# $Id$
#
# Copyright (c) 2004-2008 The FaerieMUD Consortium. Most rights reserved.
# 

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'spec'

require 'apache/fakerequest'
require 'arrow'
require 'arrow/applet'

require 'spec/lib/helpers'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::Applet do
	include Arrow::SpecHelpers

	before( :all ) do
		setup_logging( :crit )
	end

	after( :all ) do
		reset_logging()
	end


	it "has a signature even if it doesn't declare one" do
		plainclass = Class.new( Arrow::Applet )
		plainclass.signature.should be_an_instance_of( Arrow::Applet::SignatureStruct )
		plainclass.signature.members.should include( 'name' )
	end

	it "subclasses know if further subclasses of itself have been loaded" do
		plainclass = Class.new( Arrow::Applet )
		plainclass.should_not be_inherited_from()
		subclass = Class.new( plainclass )
		plainclass.should be_inherited_from()
	end

	it "raises an exception if an action method that doesn't accept arguments is declared" do
		lambda {
			Class.new( Arrow::Applet ) do
				def no_arg_action
					raise "shouldn't be callable"
				end
			end
		}.should raise_error( ::ScriptError, 'Inappropriate arity for no_arg_action' )
	end


	describe "concrete child and grandchild classes" do
		before(:each) do
			@appletclass = Class.new( Arrow::Applet ) do
				default_action :test

				applet_name "SuperApplet"
				applet_description "A superclass applet"
				applet_version 177
				applet_maintainer "ged@FaerieMUD.org"
			end
			@appletsubclass = Class.new( @appletclass )

			@applet = @appletclass.new( nil, nil, nil )
		end


		it "don't return superclass applets from ::load by default" do
			Kernel.stub!( :load ).and_return do
				Arrow::Applet.newly_loaded << @appletclass << @appletsubclass
			end

			applets = Arrow::Applet.load( 'stubbedapplet' )

			applets.should have(1).member
			applets.should_not include( @appletclass )
			applets.should include( @appletsubclass )
		end


		it "return superclass applets from ::load if asked to do so" do
			Kernel.stub!( :load ).and_return do
				Arrow::Applet.newly_loaded << @appletclass << @appletsubclass
			end

			applets = Arrow::Applet.load( 'stubbedapplet', true )

			applets.should have(2).members
			applets.should include( @appletclass )
			applets.should include( @appletsubclass )
		end


		it "inherit some values from their parent's signature" do
			@appletsubclass.signature.maintainer.should == @appletclass.signature.maintainer
			@appletsubclass.signature.maintainer.should_not be_equal(@appletclass.signature.maintainer)
		end

		it "don't inherit the :version, :name, and :description from their parent's signature" do
			@appletsubclass.signature.version.should_not == @appletclass.signature.version
			@appletsubclass.signature.name.should == @appletsubclass.name
			@appletsubclass.signature.description.should == '(none)'
		end
	end


	describe "instance" do
		before( :all ) do
			setup_logging( :crit )
		end

		before( :each ) do
			@appletclass = Class.new( Arrow::Applet ) do
				def test_action( txn, *args )
					return [txn, args]
				end

				def one_arg_action( txn, one )
					return one
				end

				def two_args_action( txn, one, two )
					return [ one, two ]
				end

				def action_missing_action( txn, missing, *args )
					return [ :missing, missing, *args ]
				end

				def load_template_action( txn, template_name )
					return self.load_template( template_name )
				end
				template :devdas, "dola/re/dola.tmpl"
			end

			@uri = '/test'
			@factory = mock( "template factory" )

			@applet = @appletclass.new( nil, @factory, @uri )

			@txn = stub( "transaction", :vargs => nil, :form_request? => false, :vargs= => nil )
		end


		it "delegates template-loading to its template factory" do
			@factory.should_receive( :get_template ).with( 'dola/re/dola.tmpl' ).
				and_return( :the_template )
			@applet.load_template_action( @txn, :devdas ).should == :the_template
		end

		it "eliminates URI arguments to match the arity of actions with only one argument" do
			@applet.run( @txn, 'one_arg', :first, :second, :third ).should == :first
		end

		it "eliminates URI arguments to match the arity of actions with two arguments" do
			@applet.run( @txn, 'two_args', :first, :second, :third ).should == [:first, :second]
		end

		it "appends nil URI arguments to match the arity of actions with two arguments" do
			@applet.run( @txn, 'two_args', :first ).should == [:first, nil]
		end


		it "maps invocations of nonexistent actions to the action_missing action" do
			@applet.run( @txn, "nonexistent", :first ).should == [ :missing, "nonexistent", :first ]
		end

		it "doesn't use libapreq's param parser for a POST with content-type " +
		        "other than 'application/www-form-url-encoded" do
			request = mock( "request", :null_object => true )
			request.should_not_receive( :paramtable )

			txn = mock( "transaction", :null_object => true )
			txn.should_receive( :form_request? ).at_least(1).and_return( false )
			txn.stub!( :request ).and_return( request )

			@applet.run( txn, 'test' )
		end

	end # describe "instance"


	describe "instance with an action that accepts form parameters" do
		before( :all ) do
			setup_logging( :crit )
		end

		it "allows a validator to be declared using 'action, hash' syntax" do
			appletclass = Class.new( Arrow::Applet ) do
				def comma_action( txn, *args )
					return 'yay'
				end

				validator :comma, :optional => :formy
			end
			appletclass.signature.validator_profiles[ :comma ].should == {
				:optional => :formy
			}
		end

		it "allows a validator to be declared using 'action => { hash }' syntax" do
			appletclass = Class.new( Arrow::Applet ) do
				def hash_action( txn, *args )
					return 'yay'
				end

				validator :hash => { :optional => :formy }
			end
			appletclass.signature.validator_profiles[ :hash ].should == {
				:optional => :formy
			}
		end
	end


	describe "instance without an #action_missing_action method" do
		before( :all ) do
			setup_logging( :crit )
		end

		before( :each ) do
			@appletclass = Class.new( Arrow::Applet ) do
				template :test => 'test.tmpl'
			end

			@uri = '/test'
			@factory = mock( "template factory" )

			@applet = @appletclass.new( nil, @factory, @uri )

			@txn = stub( "transaction", :vargs => nil, :form_request? => false, :vargs= => nil )
		end

		it "maps missing actions to like-named templates" do
			template = stub( "test template" )
			@factory.should_receive( :get_template ).with( 'test.tmpl' ).and_return( template )

			template.should_receive( :txn= ).with( @txn )
			template.should_receive( :applet= ).with( @applet )

			@applet.run( @txn, 'test' ).should == template
		end

		it "untaints the action before using it to look up the missing action template" do
			template = stub( "test template" )
			@factory.should_receive( :get_template ).with( 'test.tmpl' ).and_return( template )

			template.should_receive( :txn= ).with( @txn )
			template.should_receive( :applet= ).with( @applet )

			action = 'test'
			action.taint

			Thread.new do
				Thread.current.abort_on_exception = true
				$SAFE = 1
				lambda {
					@applet.run( @txn, action )
				}.should_not raise_error()
			end.join
		end



		### TODO: Convert these to specs

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
					# This causes a system access, which makes for stime
					# the previous code was only usertime on my linux machine -JJ
					d = Dir.open('.')
					d.close
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
				rval, *args = @applet.send( :lookup_action_method, nil, "test" )
			end

			assert_instance_of Method, rval
			assert_match( /#test_action/, rval.to_s )
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
					self.subrun( 'test_vargs', txn, *args )
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

	end # describe "concrete subclass"

end


# vim: set nosta noet ts=4 sw=4:
