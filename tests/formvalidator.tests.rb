#!/usr/bin/ruby -w
#
# Unit test for the Arrow::FormValidator class
# $Id$
#
# Copyright (c) 2004, 2005, 2006 RubyCrafters, LLC. Most rights reserved.
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


### Collection of tests for the Arrow::FormValidator class.
class Arrow::FormValidatorTestCase < Arrow::TestCase

	TestProfile = {
		:required		=> [ :required ],
		:optional		=> %w{optional number alpha int_constraint 
			bool_constraint email_constraint},
		:constraints	=> {
			:number				=> /^(\d+)$/,
			:alpha				=> /^(\w+)$/,
			:int_constraint		=> :integer,
			:bool_constraint	=> :boolean,
			:email_constraint	=> :email,
		},
		:untaint_all_constraints => true
	}


	def setup
		@validator = Arrow::FormValidator.new( TestProfile )
	end



	#################################################################
	###	T E S T S
	#################################################################

	# Test index operator interface
	def test_index_operators_should_access_valid_args
		rval = nil

		assert_respond_to @validator, :[]
		assert_respond_to @validator, "[]=".intern

		assert_nothing_raised do
			@validator.validate( {'required' => "1"} )
			rval = @validator[:required]
		end

		assert_equal "1", rval

		assert_nothing_raised do
			@validator[:required] = "bar"
		end

		assert_equal "bar", @validator["required"]
	end


	def test_missing_should_return_names_of_missing_fields
		rval = nil

		# Missing required value
		@validator.validate( {} )
		assert_nothing_raised { rval = @validator.errors? }
		assert_equal true, rval
		assert_nothing_raised { rval = @validator.okay? }
		assert_equal false, rval
	end


	def test_invalid_should_return_names_of_invalid_fields
		rval = nil

		# Invalid value
		@validator.validate( {'number' => 'rhinoceros'} )
		assert_nothing_raised { rval = @validator.errors? }
		assert_equal true, rval
		assert_nothing_raised { rval = @validator.okay? }
		assert_equal false, rval
	end


	def test_error_fields_should_return_names_of_missing_and_invalid_fields
		rval = nil

		# Invalid value
		@validator.validate( {'number' => 'rhinoceros'} )
		assert_nothing_raised do
			rval = @validator.error_fields
		end

		assert_instance_of Array, rval
		assert_equal 2, rval.length
		assert_include 'number', rval
		assert_include 'required', rval
	end


	def test_error_messages_should_return_an_array_of_error_messages
		rval = nil

		# Invalid + missing values with no descriptions
		@validator.validate( {'number' => 'rhinoceros', 'unknown' => "1"} )
		debugMsg "Validator is: %p" % [@validator]

		# Without unknown fields first
		assert_nothing_raised { rval = @validator.error_messages }
		debugMsg "Error messages: %p" % [rval]
		assert_instance_of Array, rval,
			"error messages should be contained in an Array"
		assert_equal 2, rval.nitems, "should be 2 error messages"
		assert_equal \
			["Missing value for 'Required'", "Invalid value for field 'Number'"],
			rval,
			"default error messages"
	end

	def test_error_messages_with_true_arg_should_return_error_messages_including_unknown
		rval = nil

		# With unknown fields
		@validator.validate( {'number' => 'rhinoceros', 'unknown' => "1"} )
		assert_nothing_raised { rval = @validator.error_messages(true) }
		assert_instance_of Array, rval,
			"error messages should be contained in an Array"
		assert_equal 3, rval.nitems, "should be 3 error messages"
		assert_equal \
			["Missing value for 'Required'", "Invalid value for field 'Number'",
			 "Unknown field 'Unknown'"],
			rval,
			"default error messages"
	end

	def test_error_messages_with_field_descs_should_return_error_messages_using_those_descs
		rval = nil
		descs = {
			:number => "Numeral",
			:required => "Test Name",
		}

		# With descriptions
		@validator.validate( {'number' => 'rhinoceros', 'unknown' => "1"}, 
							 {:descriptions => descs} )

		assert_nothing_raised { rval = @validator.error_messages }
		assert_instance_of Array, rval,
			"error messages should be contained in an Array"
		assert_equal 2, rval.nitems, "should be 2 error messages"
		assert_equal \
			["Missing value for 'Test Name'", "Invalid value for field 'Numeral'"],
			rval,
			"error messages with descriptions"
		
	end
	
	def test_get_description_should_return_capitalized_word_for_simple_field
		@validator.validate( {} )
		rval = nil
		
		assert_nothing_raised do
			rval = @validator.get_description( 'required' )
		end
		
		assert_equal 'Required', rval
	end

	
	def test_get_description_should_return_two_capitalized_words_for_underbarred_field
		@validator.validate( {}, :required => ['rodent_size'] )
		rval = nil
		
		assert_nothing_raised do
			rval = @validator.get_description( 'rodent_size' )
		end
		
		assert_equal 'Rodent Size', rval
	end

	
	def test_get_description_should_return_capitalized_key_word_for_hash_field
		@validator.validate( {}, :required => ['rodent[size]'] )
		rval = nil
		
		assert_nothing_raised do
			rval = @validator.get_description( 'rodent[size]' )
		end
		
		assert_equal 'Size', rval
	end

	
	def test_get_description_should_return_two_capitalized_key_words_for_hash_field_with_underbarred_key
		@validator.validate( {}, :required => ['castle[baron_id]'] )
		rval = nil
		
		assert_nothing_raised do
			rval = @validator.get_description( 'castle[baron_id]' )
		end
		
		assert_equal 'Baron Id', rval
	end

	
	def test_valid_should_return_valid_params_after_transforming_them_into_hash_one_dimension
		@validator.validate( {'rodent[size]' => 'unusual'}, :optional => ['rodent[size]'] )
		assert_equal( {"rodent" => {"size" => 'unusual'}}, @validator.valid )
	end


	def test_valid_should_return_valid_params_after_transforming_them_into_hash_two_dimension
		profile = {
			:optional => [
				'recipe[ingredient][name]',
				'recipe[ingredient][cost]',
				'recipe[yield]'
			]
		}
		args = {
			'recipe[ingredient][name]' => 'nutmeg',
			'recipe[ingredient][cost]' => '$0.18',
			'recipe[yield]' => '2 loaves',
		}
		expected = {
			"recipe" => {
				"ingredient" => { 'name' => 'nutmeg', 'cost' => '$0.18' },
				'yield' => '2 loaves'
			}
		}

		@validator.validate( args, profile )
		assert_equal( expected, @validator.valid )
	end


	def test_boolean_constraint_should_accept_true_string
		rval = nil
		params = {'required' => '1', 'bool_constraint' => 'true'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:bool_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal true, rval
	end


	def test_boolean_constraint_should_accept_t_as_true
		rval = nil
		params = {'required' => '1', 'bool_constraint' => 't'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:bool_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal true, rval
	end

	def test_boolean_constraint_should_accept_yes_as_true
		rval = nil
		params = {'required' => '1', 'bool_constraint' => 'yes'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:bool_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal true, rval
	end

	def test_boolean_constraint_should_accept_y_as_true
		rval = nil
		params = {'required' => '1', 'bool_constraint' => 'y'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:bool_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal true, rval
	end

	def test_boolean_constraint_should_accept_false_string
		rval = nil
		params = {'required' => '1', 'bool_constraint' => 'false'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:bool_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal false, rval
	end


	def test_boolean_constraint_should_accept_f_as_false
		rval = nil
		params = {'required' => '1', 'bool_constraint' => 'f'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:bool_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal false, rval
	end

	def test_boolean_constraint_should_accept_no_as_false
		rval = nil
		params = {'required' => '1', 'bool_constraint' => 'no'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:bool_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal false, rval
	end

	def test_boolean_constraint_should_accept_n_as_false
		rval = nil
		params = {'required' => '1', 'bool_constraint' => 'n'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:bool_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal false, rval
	end

	def test_boolean_constraint_should_reject_nonboolean_string
		rval = nil
		params = {'required' => '1', 'bool_constraint' => 'peanut'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:bool_constraint]
		end

		assert_equal true, @validator.errors?
		assert_equal nil, rval
	end


	def test_integer_constraint_should_accept_11
		rval = nil
		params = {'required' => '1', 'int_constraint' => '11'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:int_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal 11, rval
	end

	def test_integer_constraint_should_accept_0
		rval = nil
		params = {'required' => '1', 'int_constraint' => '0'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:int_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal 0, rval
	end

	def test_integer_constraint_should_accept_negative_11
		rval = nil
		params = {'required' => '1', 'int_constraint' => '-11'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:int_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal -11, rval
	end

	def test_integer_constraint_should_reject_noninteger_string
		rval = nil
		params = {'required' => '1', 'int_constraint' => '11.1'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:int_constraint]
		end

		assert_equal true, @validator.errors?
		assert_equal nil, rval
	end

	def test_integer_constraint_should_reject_noninteger_string2
		rval = nil
		params = {'required' => '1', 'int_constraint' => '88licks'}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:int_constraint]
		end

		assert_equal true, @validator.errors?
		assert_equal nil, rval
	end

	def test_email_constraint_should_match_simple_address
		rval = nil
		params = {
			'required' => '1',
			'email_constraint' => 'jrandom@hacker.ie',
		}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:email_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal 'jrandom@hacker.ie', rval
	end
	
	def test_email_constraint_should_match_address_with_hyphened_host
		rval = nil
		params = {
			'required' => '1',
			'email_constraint' => 'jrandom@just-another-hacquer.fr',
		}

		assert_nothing_raised do
			@validator.validate( params )
			rval = @validator[:email_constraint]
		end

		assert_equal false, @validator.errors?
		assert_equal 'jrandom@just-another-hacquer.fr', rval
	end
	
	ComplexAddresses = [
		'ruby+hacker@random-example.org',
		'"ruby hacker"@ph8675309.org',
		'jrandom@[ruby hacquer].com',
		'abcdefghijklmnopqrstuvwxyz@abcdefghijklmnopqrstuvwxyz',
	]
	def test_email_constraint_should_match_complex_addresses
		rval = nil

		ComplexAddresses.each do |addr|
			params = {
				'required' => '1',
				'email_constraint' => addr,
			}

			assert_nothing_raised do
				@validator.validate( params )
				rval = @validator[:email_constraint]
			end

			assert_equal false, @validator.errors?,
				@validator.error_messages
			assert_equal addr, rval
		end
	end

	BogusAddresses = [
		'jrandom@hacquer com',
		'jrandom@ruby hacquer.com',
		'j random@rubyhacquer.com',
		'j random@ruby|hacquer.com',
		'j:random@rubyhacquer.com',
	]
	def test_email_constraint_should_reject_bogus_addresses
		rval = nil

		BogusAddresses.each do |addr|
			params = {
				'required' => '1',
				'email_constraint' => addr,
			}

			assert_nothing_raised do
				@validator.validate( params )
				rval = @validator[:email_constraint]
			end

			#assert_equal true, @validator.errors?, addr
			assert_equal nil, rval
		end
	end
	
	
end

