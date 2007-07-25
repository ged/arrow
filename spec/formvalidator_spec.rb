#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'apache/fakerequest'
	require 'arrow'
	require 'arrow/spechelpers'
	require 'arrow/transaction'
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
TestProfile = {
	:required		=> [ :required ],
	:optional		=> %w{optional number alpha int_constraint 
		bool_constraint email_constraint host_constraint
		regexp_w_captures},
	:constraints	=> {
		:number				=> /^\d+$/,
		:alpha				=> /^\w+$/,
		:regexp_w_captures  => /(\w+)(\S+)/,
		:int_constraint		=> :integer,
		:bool_constraint	=> :boolean,
		:email_constraint	=> :email,
		:host_constraint	=> :hostname,
	},
}


describe Arrow::FormValidator do
	before( :all ) do
		outputter = Arrow::Logger::Outputter.
			create( 'color:stderr', "formvalidator-spec" )
		Arrow::Logger::global.outputters << outputter
		Arrow::Logger::global.level = :crit
	end
	
	before(:each) do
		@validator = Arrow::FormValidator.new( TestProfile )
	end

	after( :all ) do
		Arrow::Logger.global.outputters.clear
	end

	

	# Test index operator interface
	it "should provide read and write access to valid args via the index operator" do
		rval = nil
		
		@validator.validate( {'required' => "1"} )
		@validator[:required].should == "1"

		@validator[:required] = "bar"
		@validator["required"].should == "bar"
	end


	it "should untaint valid args if told to do so" do
		rval = nil
		tainted_one = "1"
		tainted_one.taint
		
		@validator.validate( {'required' => 1, 'number' => tainted_one},
			:untaint_all_constraints => true )
			
		Arrow::Logger.global.notice "Validator: %p" % [@validator]
			
		@validator[:number].should == "1"
		@validator[:number].tainted?.should be_false()
	end


	it "should return the captures from a regexp constraint if it has them" do
		rval = nil
		params = { 'required' => 1, 'regexp_w_captures' => "   the1tree(!)   " }
		
		@validator.validate( params, :untaint_all_constraints => true )
			
		Arrow::Logger.global.notice "Validator: %p" % [@validator]
			
		@validator[:regexp_w_captures].should == ['the1tree', '(!)']
	end

	it "knows the names of fields that were required but missing from the parameters" do
		@validator.validate( {} )

		@validator.should have_errors()
		@validator.should_not be_okay()
		
		@validator.missing.should have(1).members
		@validator.missing.should == ['required']
	end

	it "knows the names of fields that did not meet their constraints" do
		params = {'number' => 'rhinoceros'}
		@validator.validate( params )

		@validator.should have_errors()
		@validator.should_not be_okay()
		
		@validator.invalid.should have(1).keys
		@validator.invalid.keys.should == ['number']
	end

	it "can return a combined list of all problem parameters, which includes " +
		" both missing and invalid fields" do
		params = {'number' => 'rhinoceros'}
		@validator.validate( params )

		@validator.should have_errors()
		@validator.should_not be_okay()
		
		@validator.error_fields.should have(2).members
		@validator.error_fields.should include('number')
		@validator.error_fields.should include('required')
	end

	it "can return human descriptions of validation errors" do
		params = {'number' => 'rhinoceros', 'unknown' => "1"}
		@validator.validate( params )

		@validator.error_messages.should have(2).members
		@validator.error_messages.should include("Missing value for 'Required'")
		@validator.error_messages.should include("Invalid value for 'Number'")
	end

	it "can include unknown fields in its human descriptions of validation errors" do
		params = {'number' => 'rhinoceros', 'unknown' => "1"}
		@validator.validate( params )

		@validator.error_messages(true).should have(3).members
		@validator.error_messages(true).should include("Missing value for 'Required'")
		@validator.error_messages(true).should include("Invalid value for 'Number'")
		@validator.error_messages(true).should include("Unknown parameter 'Unknown'")
	end

	it "can use provided descriptions of parameters when constructing human " +
		"validation error messages" do
		descs = {
			:number => "Numeral",
			:required => "Test Name",
		}
		params = {'number' => 'rhinoceros', 'unknown' => "1"}
		@validator.validate( params, :descriptions => descs )

		@validator.error_messages.should have(2).members
		@validator.error_messages.should include("Missing value for 'Test Name'")
		@validator.error_messages.should include("Invalid value for 'Numeral'")
	end


	it "capitalizes the names of simple fields for descriptions" do
		@validator.get_description( "required" ).should == 'Required'
	end
	
	it "splits apart underbarred field names into capitalized words for descriptions" do
		@validator.get_description( "rodent_size" ).should == 'Rodent Size'
	end
	
	it "uses the key for descriptions of hash fields" do
		@validator.get_description( "rodent[size]" ).should == 'Size'
	end

	it "uses separate capitalized words for descriptions of hash fields with underbarred keys " do
		@validator.get_description( "castle[baron_id]" ).should == 'Baron Id'
	end

	it "should be able to coalesce simple hash fields into a hash of validated values" do
		@validator.validate( {'rodent[size]' => 'unusual'}, :optional => ['rodent[size]'] )

		@validator.valid.should == {'rodent' => {'size' => 'unusual'}}
	end

	it "should be able to coalesce complex hash fields into a nested hash of validated values" do
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
	
		@validator.validate( args, profile )
		@validator.valid.should == {
			'recipe' => {
				'ingredient' => { 'name' => 'nutmeg', 'cost' => '$0.18' },
				'yield' => '2 loaves'
			}
		}
	end

	it "accepts the value 'true' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'true'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_true()
	end
	
	it "accepts the value 't' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 't'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_true()
	end
	
	it "accepts the value 'yes' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'yes'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_true()
	end
	
	it "accepts the value 'y' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'y'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_true()
	end
	
	it "accepts the value 'false' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'false'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_false()
	end
	
	it "accepts the value 'f' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'f'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_false()
	end
	
	it "accepts the value 'no' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'no'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_false()
	end
	
	it "accepts the value 'n' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'n'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_false()
	end

	it "rejects non-boolean parameters for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'peanut'}
	
		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:bool_constraint].should be_nil()
	end
	
	it "accepts simple integers for fields with integer constraints" do
		params = {'required' => '1', 'int_constraint' => '11'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:int_constraint].should == 11
	end
	
	it "accepts '0' for fields with integer constraints" do
		params = {'required' => '1', 'int_constraint' => '0'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:int_constraint].should == 0
	end
	
	it "accepts negative integers for fields with integer constraints" do
		params = {'required' => '1', 'int_constraint' => '-407'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:int_constraint].should == -407
	end
	
	it "rejects non-integers for fields with integer constraints" do
		params = {'required' => '1', 'int_constraint' => '11.1'}
	
		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:int_constraint].should be_nil()
	end
	
	it "rejects integer values with other cruft in them for fields with integer constraints" do
		params = {'required' => '1', 'int_constraint' => '88licks'}
	
		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:int_constraint].should be_nil()
	end
	
	it "accepts simple RFC822 addresses for fields with email constraints" do
		params = {'required' => '1', 'email_constraint' => 'jrandom@hacker.ie'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:email_constraint].should == 'jrandom@hacker.ie'
	end

	it "accepts hyphenated domains in RFC822 addresses for fields with email constraints" do
		params = {'required' => '1', 'email_constraint' => 'jrandom@just-another-hacquer.fr'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:email_constraint].should == 'jrandom@just-another-hacquer.fr'
	end

	ComplexAddresses = [
		'ruby+hacker@random-example.org',
		'"ruby hacker"@ph8675309.org',
		'jrandom@[ruby hacquer].com',
		'abcdefghijklmnopqrstuvwxyz@abcdefghijklmnopqrstuvwxyz',
	]
	it "accepts complex RFC822 addresses for fields with email constraints" do
		ComplexAddresses.each do |addy|
			params = {'required' => '1', 'email_constraint' => addy}
	
			@validator.validate( params )

			@validator.should be_okay()
			@validator.should_not have_errors()

			@validator[:email_constraint].should == addy
		end
	end


	BogusAddresses = [
		'jrandom@hacquer com',
		'jrandom@ruby hacquer.com',
		'j random@rubyhacquer.com',
		'j random@ruby|hacquer.com',
		'j:random@rubyhacquer.com',
	]
	it "rejects bogus RFC822 addresses for fields with email constraints" do
		BogusAddresses.each do |addy|
			params = {'required' => '1', 'email_constraint' => addy}
	
			@validator.validate( params )

			@validator.should_not be_okay()
			@validator.should have_errors()

			@validator[:email_constraint].should be_nil()
		end
	end

	it "accepts simple hosts for fields with host constraints" do
		params = {'required' => '1', 'host_constraint' => 'deveiate.org'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:host_constraint].should == 'deveiate.org'
	end

	it "accepts hyphenated hosts for fields with host constraints" do
		params = {'required' => '1', 'host_constraint' => 'your-characters-can-fly.kr'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:host_constraint].should == 'your-characters-can-fly.kr'
	end

	BogusHosts = [
		'.',
		'glah ',
		'glah[lock]',
		'glah.be$',
		'indus«tree».com',
	]

	it "rejects hostnames for fields with host constraints" do
		BogusHosts.each do |hostname|
			params = {'required' => '1', 'host_constraint' => hostname}
	
			@validator.validate( params )

			@validator.should_not be_okay()
			@validator.should have_errors()

			@validator[:host_constraint].should be_nil()
		end
	end

end

