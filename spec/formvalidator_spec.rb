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
	require 'date'
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
	:optional		=> %w{
		optional number int_constraint bool_constraint email_constraint
        host_constraint regexp_w_captures regexp_w_one_capture
        alpha_constraint alphanumeric_constraint printable_constraint
		proc_constraint uri_constraint
	},
	:constraints	=> {
		:number                  => /^\d+$/,
		:regexp_w_captures       => /(\w+)(\S+)?/,
		:regexp_w_one_capture    => /(\w+)/,
		:int_constraint          => :integer,
		:bool_constraint         => :boolean,
		:email_constraint        => :email,
		:uri_constraint          => :uri,
		:host_constraint         => :hostname,
		:alpha_constraint        => :alpha,
		:alphanumeric_constraint => :alphanumeric,
		:printable_constraint    => :printable,
		:proc_constraint         => Proc.new {|d| Date.parse(d) rescue nil },
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


	it "should return the capture from a regexp constraint if it has only one" do
		rval = nil
		params = { 'required' => 1, 'regexp_w_one_capture' => "   ygdrassil   " }
		
		@validator.validate( params, :untaint_all_constraints => true )
			
		Arrow::Logger.global.notice "Validator: %p" % [@validator]
			
		@validator[:regexp_w_one_capture].should == 'ygdrassil'
	end

	it "should return the captures from a regexp constraint as an array if it has more than one" do
		rval = nil
		params = { 'required' => 1, 'regexp_w_captures' => "   the1tree(!)   " }
		
		@validator.validate( params, :untaint_all_constraints => true )
			
		Arrow::Logger.global.notice "Validator: %p" % [@validator]
			
		@validator[:regexp_w_captures].should == ['the1tree', '(!)']
	end

	it "should return the captures from a regexp constraint as an array " +
		"even if an optional capture doesn't match anything" do
		rval = nil
		params = { 'required' => 1, 'regexp_w_captures' => "   the1tree   " }
		
		@validator.validate( params, :untaint_all_constraints => true )
			
		Arrow::Logger.global.notice "Validator: %p" % [@validator]
			
		@validator[:regexp_w_captures].should == ['the1tree', nil]
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
	
	ValidURIs = %w{
		http://127.0.0.1
		http://127.0.0.1/
		http://[127.0.0.1]/
		http://ruby-lang.org/
		http://www.rocketboom.com/vlog/rb_08_feb_01
		http://del.icio.us/search/?fr=del_icio_us&p=ruby+arrow&type=all
		http://[FEDC:BA98:7654:3210:FEDC:BA98:7654:3210]:8080/index.html
		http://[1080:0:0:0:8:800:200C:417A]/index.html
		http://[3ffe:2a00:100:7031::1]
		http://[1080::8:800:200C:417A]/foo
		http://[::192.9.5.5]/ipng
		http://[::FFFF:129.144.52.38]:3474/index.html
		http://[2010:836B:4179::836B:4179]

		https://mail.google.com/
		https://127.0.0.1/
		https://r4.com:8080/

		ftp://ftp.ruby-lang.org/pub/ruby/1.0/ruby-0.49.tar.gz
		ftp://crashoverride:god@gibson.ellingsonmineral.com/root/.workspace/.garbage.
		
		ldap:/o=University%20of%20Michigan,c=US
		ldap://ldap.itd.umich.edu/o=University%20of%20Michigan,c=US
		ldap://ldap.itd.umich.edu/o=University%20of%20Michigan,c=US?postalAddress
		ldap://host.com:6666/o=University%20of%20Michigan,c=US??sub?(cn=Babs%20Jensen)
		ldap://ldap.itd.umich.edu/c=GB?objectClass?one
		ldap://ldap.question.com/o=Question%3f,c=US?mail
		ldap://ldap.netscape.com/o=Babsco,c=US??(int=%5c00%5c00%5c00%5c04)
		ldap:/??sub??bindname=cn=Manager%2co=Foo
		ldap:/??sub??!bindname=cn=Manager%2co=Foo
	  }

	ValidURIs.each do |uri_string|
		it "accepts #{uri_string} for fields with URI constraints" do
			params = {'required' => '1', 'uri_constraint' => uri_string}
	
			@validator.validate( params )

			@validator.should be_okay()
			@validator.should_not have_errors()

			@validator[:uri_constraint].should be_a_kind_of( URI::Generic )
			@validator[:uri_constraint].to_s.should == uri_string
		end
	end

	# :FIXME: I don't know LDAP uris very well, so I'm not sure how they're likely to
	# be invalidly-occurring in the wild
	InvalidURIs = %W{
		glark:
		
		http:
		http://
		http://_com/vlog/rb_08_feb_01
		http://del.icio.us/search/\x20\x14\x18
		http://FEDC:BA98:7654:3210:FEDC:BA98:7654:3210/index.html
		http://1080:0:0:0:8:800:200C:417A/index.html
		http://3ffe:2a00:100:7031::1
		http://1080::8:800:200C:417A/foo
		http://::192.9.5.5/ipng
		http://::FFFF:129.144.52.38:80/index.html
		http://2010:836B:4179::836B:4179

		https:
		https://user:pass@/
		https://r4.com:nonnumericport/

		ftp:
		ftp:ruby-0.49.tar.gz
		ftp://crashoverride:god@/root/.workspace/.garbage.
		
		ldap:
		ldap:/o=University\x20of\x20Michigan,c=US
		ldap://ldap.itd.umich.edu/o=University+\x00of+Michigan
	  }

	InvalidURIs.each do |uri_string|
		it "rejects #{uri_string} for fields with URI constraints" do
			params = {'required' => '1', 'uri_constraint' => uri_string}
	
			# lambda {
				@validator.validate( params )
			# }.should_not raise_error()

			@validator.should_not be_okay()
			@validator.should have_errors()

			@validator[:uri_constraint].should be_nil()
		end
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
	ComplexAddresses.each do |addy|
		it "accepts #{addy} for fields with email constraints" do
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
	BogusAddresses.each do |addy|
		it "rejects #{addy} for fields with email constraints" do
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

	BogusHosts.each do |hostname|
		it "rejects #{hostname} for fields with host constraints" do
			params = {'required' => '1', 'host_constraint' => hostname}
	
			@validator.validate( params )

			@validator.should_not be_okay()
			@validator.should have_errors()

			@validator[:host_constraint].should be_nil()
		end
	end

	it "accepts alpha characters for fields with alpha constraints" do
		params = {'required' => '1', 'alpha_constraint' => 'abelincoln'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:alpha_constraint].should == 'abelincoln'
	end
	
	it "rejects non-alpha characters for fields with alpha constraints" do
		params = {'required' => '1', 'alpha_constraint' => 'duck45'}
	
		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:alpha_constraint].should be_nil()
	end
	
	### 'alphanumeric'
	it "accepts alphanumeric characters for fields with alphanumeric constraints" do
		params = {'required' => '1', 'alphanumeric_constraint' => 'zombieabe11'}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:alphanumeric_constraint].should == 'zombieabe11'
	end
	
	it "rejects non-alphanumeric characters for fields with alphanumeric constraints" do
		params = {'required' => '1', 'alphanumeric_constraint' => 'duck!ling'}
	
		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:alphanumeric_constraint].should be_nil()
	end
	
	### 'printable'
	it "accepts printable characters for fields with 'printable' constraints" do
		test_content = <<-EOF
		I saw you with some kind of medical apparatus strapped to your
        spine. It was all glass and metal, a great crystaline hypodermic
        spider, carrying you into the aether with a humming, crackling sound.
		EOF

		params = {
			'required' => '1',
			'printable_constraint' => test_content
		}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:printable_constraint].should == test_content
	end
	
	it "rejects non-printable characters for fields with 'printable' constraints" do
		params = {'required' => '1', 'printable_constraint' => %{\0Something cold\0}}
	
		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:printable_constraint].should be_nil()
	end
	
	
	it "accepts parameters for fields with Proc constraints if the Proc " +
		"returns a true value" do
		test_date = '2007-07-17'
		params = {'required' => '1', 'proc_constraint' => test_date}
	
		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:proc_constraint].should == Date.parse( test_date )
	end
	
	it "rejects parameters for fields with Proc constraints if the Proc " +
		"returns a false value" do

		params = {'required' => '1', 'proc_constraint' => %{::::}}
	
		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:proc_constraint].should be_nil()
	end
	
end

