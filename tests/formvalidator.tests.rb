#!/usr/bin/ruby -w
#
# Unit test for the Arrow::FormValidator class
# $Id$
#
# Copyright (c) 2004, 2005 RubyCrafters, LLC. Most rights reserved.
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


### Collection of tests for the Arrow::FormValidator class.
class Arrow::FormValidatorTestCase < Arrow::TestCase

	TestProfile = {
		:required		=> [ :required ],
		:optional		=> %w{optional number alpha},
		:constraints	=> {
			:number	=> /^(\d+)$/,
			:alpha	=> /^(\w+)$/,
		},
		:untaint_all_constraints => true
	}


	#################################################################
	###	T E S T S
	#################################################################

	# Simple instantiation
	def test_00_Instantiate
		printTestHeader "FormValidator: Instantiate"
		obj = rval = nil

		assert_nothing_raised do
			obj = Arrow::FormValidator::new
		end

		assert_instance_of Arrow::FormValidator, obj
		assert obj.instance_variables.include?( "@descriptions" ),
			"formvalidator should have an ivar called '@descriptions'"
	end

	
	# Test index operator interface
	def test_10_index
		printTestHeader "FormValidator: Index ops"
		rval = nil
		validator = Arrow::FormValidator::new

		assert_respond_to validator, :[]
		assert_respond_to validator, "[]=".intern

		assert_nothing_raised do
			validator.validate( {'required' => "1"}, TestProfile )
			rval = validator[:required]
		end

		assert_equal "1", rval

		assert_nothing_raised do
			validator[:required] = "bar"
		end

		assert_equal "bar", validator["required"]
	end

	def test_20_missing
		printTestHeader "FormValidator: Missing value"
		rval = nil

		# Missing required value
		validator = Arrow::FormValidator::new
		validator.validate( {}, TestProfile )
		assert_nothing_raised { rval = validator.errors? }
		assert_equal true, rval
		assert_nothing_raised { rval = validator.okay? }
		assert_equal false, rval
	end

	def test_30_invalid
		printTestHeader "FormValidator: Invalid value"
		rval = nil

		# Invalid value
		validator = Arrow::FormValidator::new
		validator.validate( {'number' => 'rhinoceros'}, TestProfile )
		assert_nothing_raised { rval = validator.errors? }
		assert_equal true, rval
		assert_nothing_raised { rval = validator.okay? }
		assert_equal false, rval
	end

	def test_40_errormessages
		printTestHeader "FormValidator: Invalid value"
		rval = nil
		descs = {
			:number => "Numeral",
			:required => "Test Name",
		}

		# Invalid + missing values with no descriptions
		validator = Arrow::FormValidator::new
		validator.validate( {'number' => 'rhinoceros', 'unknown' => "1"}, TestProfile )
		debugMsg "Validator is: %p" % [validator]

		# Without unknown fields first
		assert_nothing_raised { rval = validator.errorMessages }
		debugMsg "Error messages: %p" % [rval]
		assert_instance_of Array, rval,
			"error messages should be contained in an Array"
		assert_equal 2, rval.nitems, "should be 2 error messages"
		assert_equal \
			["Missing required field 'required'", "Invalid value for field 'number'"],
			rval,
			"default error messages"

		# With unknown fields
		assert_nothing_raised { rval = validator.errorMessages(true) }
		assert_instance_of Array, rval,
			"error messages should be contained in an Array"
		assert_equal 3, rval.nitems, "should be 3 error messages"
		assert_equal \
			["Missing required field 'required'", "Invalid value for field 'number'",
			 "Unknown field 'unknown'"],
			rval,
			"default error messages"

		# With descriptions
		validator = Arrow::FormValidator::new
		profile = TestProfile.merge( {:descriptions => descs} )
		validator.validate( {'number' => 'rhinoceros', 'unknown' => "1"}, profile )

		assert_nothing_raised { rval = validator.errorMessages }
		assert_instance_of Array, rval,
			"error messages should be contained in an Array"
		assert_equal 2, rval.nitems, "should be 2 error messages"
		assert_equal \
			["Missing required field 'Test Name'", "Invalid value for field 'Numeral'"],
			rval,
			"error messages with descriptions"
		
	end
end

