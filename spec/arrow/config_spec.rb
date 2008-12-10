#!/usr/bin/env ruby
# 
# Specification for the Arrow::Config class
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

begin
	require 'spec'
	require 'apache/fakerequest'
	require 'arrow'
	require 'arrow/config'

	require 'spec/lib/helpers'
	require 'spec/lib/constants'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include Arrow::TestConstants


#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::Config do
	include Arrow::SpecHelpers
	
	before( :all ) do
		setup_logging( :debug )
	end
	
	after( :all ) do
		reset_logging()
	end



	#################################################################
	###	E X A M P L E S
	#################################################################

	describe Arrow::Config::ConfigStruct do
		
		it "can be constructed from a Hash" do
			struct = Arrow::Config::ConfigStruct.new( TEST_CONFIG_HASH )
			struct.should have(5).members
		end
		
		describe "instance" do
			before( :each ) do
				@struct = Arrow::Config::ConfigStruct.new( TEST_CONFIG_HASH )
			end

			it "knows what its keys are" do
				@struct.keys.should have( TEST_CONFIG_HASH.length ).members
				@struct.keys.should include( *TEST_CONFIG_HASH.keys )
			end

			it "knows if it has a particular key" do
				@struct.should have_key( :templates )
			end
		
			it "can look up its values via the Hash index interface" do
				@struct[:applets][:path].should == TEST_CONFIG_HASH[:applets][:path]
			end
			
			it "can turn itself back into a Hash" do
				@struct.to_hash.should == TEST_CONFIG_HASH
			end
			
		end
		
	end
	

	it "has reasonable defaults when instantiated without arguments" do
		config = Arrow::Config.new
		config.to_hash.should == Arrow::Config::DEFAULTS
	end


	it "can be initialized with a Hash" do
		config = Arrow::Config.new( TEST_CONFIG_HASH.dup )
		config.to_hash.should == TEST_CONFIG_HASH
	end
	

	### Test instantiation of the Config class with configuration values.
	def test_11_InstantiationWithArgs
		printTestHeader "Arrow::Config: Instantiation with arguments"
		rval = config = nil

		assert_nothing_raised {
			config = Arrow::Config.new( TestConfig )
		}
		assert_instance_of Arrow::Config, config

		# The configuration values should be the test config merged with the
		# defaults for the config class.
		(TestConfig.keys|Arrow::Config::DEFAULTS.keys).each {|key|
			val = TestConfig[key] || Arrow::Config::DEFAULTS[key]
			assert_nothing_raised { rval = config.send(key) }
			assert_config_equal val, rval, key
		}
	end


	### Test the abstract Config::Loader class.
	def test_30_Loader
		printTestHeader "Arrow::Config: Loader base class"
		rval = loader = nil
		createTime = Time.now

		assert_nothing_raised { loader = Arrow::Config::Loader.create('test') }
		assert_kind_of Arrow::Config::Loader, loader

		# The #load method
		assert_respond_to loader, :load
		assert_nothing_raised { rval = loader.load("foo") }
		assert_instance_of Hash, rval
		assert rval.key?( :applets ), "Loaded hash has an :applets key"
		assert rval.key?( :templates ), "Loaded hash has a :templates key"

		# The #save method
		assert_respond_to loader, :save
		assert_nothing_raised { loader.save(rval, "foo") }
	end


	### Test the .create method of Loader with the YAML Loader class.
	def test_31_CreateYamlLoader
		printTestHeader "Arrow::Config: YAML loader"
		loader = rval = nil

		assert_nothing_raised {
			loader = Arrow::Config::Loader.create( 'yaml' )
		}
		assert_kind_of Arrow::Config::Loader, loader

		assert_nothing_raised {
			loader = Arrow::Config::Loader.create( 'YAML' )
		}
		assert_kind_of Arrow::Config::Loader, loader

		assert_nothing_raised {
			loader = Arrow::Config::Loader.create( 'Yaml' )
		}
		assert_kind_of Arrow::Config::Loader, loader
	end


	### Write config
	def test_40_ConfigWriteRead
		printTestHeader "Arrow::Config: #write and #read"
		
		config = Arrow::Config.new( TestConfig )
		assert_nothing_raised {
			config.write( TestConfigFilename )
		}

		otherConfig = Arrow::Config.load( TestConfigFilename )

		assert_config_equal config.struct, otherConfig.struct
	end


	### Changed predicate knows something has changed after regular set
	def test_50_changed_after_set
		printTestHeader "Arrow::Config: #changed? after .member="
		rval = nil
		config = Arrow::Config.new( TestConfig )

		# Make sure the brand-new config struct knows it's unchanged
		assert_nothing_raised do
			rval = config.changed?
		end
		assert_equal false, rval

		# Change something via the regular accessors
		config.templates.cache = false

		# Make sure it knows something changed
		assert_nothing_raised do
			rval = config.changed?
		end
		assert_equal true, rval
	end


	### "Changed" predicate knows something has changed after merge-in-place
	def test_55_changed_after_merge
		printTestHeader "Arrow::Config: #changed? after #merge!"
		rval = nil
		config = Arrow::Config.new( TestConfig )
		config2 = Arrow::Config.new()

		# Now merge the defaults back into the test config
		config.merge!( config2 )

		# Make sure it knows something changed
		assert_nothing_raised do
			rval = config.changed?
		end
		assert_equal true, rval
	end

end
