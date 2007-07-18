#!/usr/bin/env ruby -w
#
# Unit test for the mixins contained in mixins.rb
# $Id$
#
# Copyright (c) 2006 RubyCrafters, LLC. Most rights reserved.
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

require 'flexmock'
require 'arrow/mixins'

### Collection of tests for the mixins contained in mixins.rb.
class Arrow::MixinsTestCase < Arrow::TestCase

	class TestObject
		include Arrow::Configurable
	end

	class DetailedTestObject
		include Arrow::Configurable
		config_key :foo
		
		@config = nil
		
		def self::configure( config, dispatcher )
			config.passed
			dispatcher.passed
		end
	end
	

	#################################################################
	###	T E S T S
	#################################################################

	def test_mixing_in_loggable_should_add_log_method
		testclass = Class.new do
			include Arrow::Loggable
		end
		
		assert_respond_to testclass.new, :log
	end


	def test_mixing_in_configurable_should_add_default_configure_class_method
		assert_respond_to TestObject, :configure
		assert_raises( NotImplementedError ) do
			TestObject.configure( nil, nil )
		end
	end


	def test_configurable_mixin_should_disallow_extension_of_non_module_objects
		assert_raises( ArgumentError ) do
			"foo".extend( Arrow::Configurable )
		end
	end
	

	def test_configurable_classes_should_have_a_default_config_key
		rval = nil
		
		assert_nothing_raised do
			rval = TestObject.config_key
		end
		
		assert_equal :mixinstestcase_testobject, rval
	end
	
	def test_configurable_classes_should_be_able_set_their_config_key
	    rval = nil
	    
	    assert_nothing_raised do
	        rval = DetailedTestObject.config_key
        end
        
        assert_equal :foo, rval
    end

    def test_configure_modules_should_pass_requested_section_to_modules_if_it_exists
        FlexMock.use( "config", "foosection", "dispatcher" ) do |config, foosection, dispatcher|
            config.should_receive( :member? ).
                with( :foo ).
                and_return( true ).once
            config.should_receive( :foo ).
                and_return( foosection ).once

			config.should_receive( :member? ).
				with( Symbol ).
				and_return( false )

            foosection.should_receive( :passed ).once
			dispatcher.should_receive( :passed ).once
            
            Arrow::Configurable.configure_modules( config, dispatcher )
        end
    end



    ### Injectable
    def test_load_class_loads_derivative_class
		rval = rval2 = nil
		
		assert_nothing_raised do
			rval = Arrow::Injectable.load_class( 'InjectableObject' )
			rval2 = Arrow::Injectable.load_class( 'InjectableObject' )
		end
		
		assert_instance_of Class, rval
		assert_equal "InjectableObject", rval.name
		assert_instance_of Class, rval2
		assert_equal "InjectableObject", rval2.name
	end
	
end


