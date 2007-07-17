#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Config class
# $Id$
#
# Copyright (c) 2003, 2004, 2005 RubyCrafters, LLC. Most rights reserved.
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

require 'arrow/config'


### Collection of tests for the Arrow::Config class.
class Arrow::ConfigTestCase < Arrow::TestCase

	# Testing config values
	TestConfig = {
		:applets => {
			:path	=> Arrow::Path.new( "apps:/www/apps" ),
		},
		:templates => {
			:loader => 'Arrow::Template',
			:path  => Arrow::Path.new( "templates:/www/templates" ),
			:cache => true,
			:cacheConfig => {
				:maxNum => 20,
				:maxSize => (1<<17) * 20,
			},
		},
	}
	TestConfig.freeze

	# The name of the testing configuration file
	TestConfigFilename = File.join( File.dirname(__FILE__), "testconfig.conf" )

	# Testing Config::Loader class
	class TestLoader < Arrow::Config::Loader
		def initialize( *args )
			super
			@savedConfig = nil
		end

		def load( name )
			return @savedConfig || TestConfig
		end

		def save( hash, name )
			@savedConfig = hash
		end

		def isNewer?( name, time )
			false
		end
	end


	#################################################################
	###	M E T H O D S
	#################################################################
	
	### Compare +expected+ config value to +actual+.
	def assert_config_equal( expected, actual, msg=nil )
		case expected
		when Arrow::Config::ConfigStruct
			assert_instance_of Arrow::Config::ConfigStruct, actual, msg
			expected.each {|key,val|
				rval = nil
				assert_nothing_raised { rval = actual.__send__(key) }
				assert_config_equal val, rval, "#{msg}: #{key} member"
			}

		when Hash
			assert_hash_equal expected, actual

		when Arrow::Path
			assert_instance_of Arrow::Path, actual

		else
			assert_equal expected, actual, msg
		end
	rescue Test::Unit::AssertionFailedError => err
		bt = err.backtrace
		debugMsg "Unaltered backtrace is:\n  ", bt.join("\n  ")
		cutframe = bt.reverse.find {|frame|
			/assert_config_equal/ =~ frame
		}
		debugMsg "Found frame #{cutframe}"
		firstIdx = bt.rindex( cutframe ) || 0
		#firstIdx += 1
		
		$stderr.puts "Backtrace (frame #{firstIdx}): "
		bt.each_with_index do |frame,i|
			if i < firstIdx
				debugMsg "  %s (elided)" % frame
			elsif i == firstIdx
				debugMsg "--- cutframe ------\n", frame, "\n--------------------"
			else
				debugMsg "  %s" % frame
			end
		end

		Kernel.raise( err, err.message, bt[firstIdx..-1] )
	end

	def setup
		File.delete( TestConfigFilename ) if
			File.exists?( TestConfigFilename )
		@struct = Arrow::Config::ConfigStruct.new( TestConfig )
	end
	alias_method :set_up, :setup

	def teardown
		File.delete( TestConfigFilename ) if
			File.exists?( TestConfigFilename )
    		@struct = nil
	end
	alias_method :tear_down, :teardown



	#################################################################
	###	T E S T S
	#################################################################

	def test_struct_can_behave_as_a_hash
        [:keys, :key?, :values, :value?, :[], :[]=, :length, :empty?, :clear].each do |meth|
		    assert_respond_to @struct, meth
	    end
    end

    def test_config_struct_reflects_structure_of_config_hash
        rval = nil
        
		# :TODO: This whole block should really be factored into something that
		# can traverse the whole TestConfig recursively to test more then 2-deep
		# methods.
		TestConfig.each do |key, val|

			# Response predicate
			assert_nothing_raised { rval = @struct.respond_to?(key) }
			assert_equal true, rval, "respond_to?( #{key.inspect} )"
			assert_nothing_raised { rval = @struct.respond_to?("#{key}=") }
			assert_equal true, rval, "respond_to?( #{key.inspect}= )"
			assert_nothing_raised { rval = @struct.respond_to?("#{key}?") }
			assert_equal true, rval, "respond_to?( #{key.inspect}? )"

			# Get
			assert_nothing_raised { rval = @struct.send(key) }
			assert_config_equal val, rval, "#{key}"

			# Get via index operator
			assert_nothing_raised { rval = @struct[key] }
			assert_config_equal val, rval, "#{key}"
			
			# Predicate
			assert_nothing_raised { rval = @struct.send("#{key}?") }
			if val
				assert_equal true, rval
			else
				assert_equal false, rval
			end

			# Set (and test get again to make sure it actually set a correct value)
			assert_nothing_raised { @struct.send("#{key}=", val) }
			assert_nothing_raised { rval = @struct.send(key) }
			assert_config_equal val, rval, "#{key} after #{key}="
		end
	end


	### Test ConfigStruct hashification
	def test_06_ConfigStructToHash
		printTestHeader "Arrow::Config: Hashification of ConfigStructs"
		struct = rval = nil

		struct = Arrow::Config::ConfigStruct.new( TestConfig )
		
		# Call all member methods to convert subhashes to ConfigStructs
		TestConfig.each {|key,val| struct.send(key) }

		assert_nothing_raised { rval = struct.to_h }
		assert_instance_of Hash, rval
		assert_hash_equal TestConfig, rval
	end

	
	#### Test instantiation of the Config class
	def test_10_InstantiationWithoutArgs
		printTestHeader "Arrow::Config: Instantiation without arguments"
		rval = config = nil

		assert_nothing_raised { config = Arrow::Config.new }
		assert_instance_of Arrow::Config, config

		Arrow::Config::DEFAULTS.each {|key,val|
			assert_nothing_raised { rval = config.send(key) }
			assert_config_equal val, rval, key
		}

		# Test for delegated methods
		[:to_h, :members, :member?, :each, :merge, :merge!].each {|sym|
			assert_respond_to config, sym
		}
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
