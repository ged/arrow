#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Config class
# $Id: 01_config.tests.rb,v 1.4 2003/11/09 22:44:50 deveiant Exp $
#
# Copyright (c) 2003, 2004 RubyCrafters, LLC. Most rights reserved.
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

require 'arrow/config'


### Collection of tests for the Arrow::Config class.
class Arrow::ConfigTestCase < Arrow::TestCase

	# Testing config values
	TestConfig = {
		:applets => {
			:path	=> Arrow::Path::new( "apps:/www/apps" ),
		},
		:templates => {
			:loader => 'Arrow::Template',
			:path  => Arrow::Path::new( "templates:/www/templates" ),
			:cache => true,
			:cacheConfig => {
				:maxNum => 20,
				:maxSize => (1<<17) * 20,
			},
		},
	}
	TestConfig.freeze

	# The name of the testing configuration file
	TestConfigFilename = File::join( File::dirname(__FILE__), "testconfig.conf" )

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

		Kernel::raise( err, err.message, bt[firstIdx..-1] )
	end

	def setup
		File::delete( TestConfigFilename ) if
			File::exists?( TestConfigFilename )
	end
	alias_method :set_up, :setup

	def teardown
		File::delete( TestConfigFilename ) if
			File::exists?( TestConfigFilename )
	end
	alias_method :tear_down, :teardown



	#################################################################
	###	T E S T S
	#################################################################

	### Classes test
	def test_00_Classes
		printTestHeader "Arrow::Config: Classes"

		assert_instance_of Class, Arrow::Config
		assert_instance_of Class, Arrow::Config::ConfigStruct
		assert_instance_of Class, Arrow::Config::Loader
	end


	### Test the ConfigStruct class
	def test_05_ConfigStruct
		printTestHeader "Arrow::Config: ConfigStruct class"
		struct = rval = nil

		assert_nothing_raised {
			struct = Arrow::Config::ConfigStruct::new( TestConfig )
		}
		assert_instance_of Arrow::Config::ConfigStruct, struct

		# :TODO: This whole block should really be factored into something that
		# can traverse the whole TestConfig recursively to test more then 2-deep
		# methods.
		TestConfig.each {|key, val|

			# Response predicate
			assert_nothing_raised { rval = struct.respond_to?(key) }
			assert_equal true, rval, "respond_to?( #{key.inspect} )"
			assert_nothing_raised { rval = struct.respond_to?("#{key}=") }
			assert_equal true, rval, "respond_to?( #{key.inspect}= )"
			assert_nothing_raised { rval = struct.respond_to?("#{key}?") }
			assert_equal true, rval, "respond_to?( #{key.inspect}? )"

			# Get
			assert_nothing_raised { rval = struct.send(key) }
			assert_config_equal val, rval, "#{key}"
			
			# Predicate
			assert_nothing_raised { rval = struct.send("#{key}?") }
			if val
				assert_equal true, rval
			else
				assert_equal false, rval
			end

			# Set (and test get again to make sure it actually set a correct value)
			assert_nothing_raised { struct.send("#{key}=", val) }
			assert_nothing_raised { rval = struct.send(key) }
			assert_config_equal val, rval, "#{key} after #{key}="
		}
	end


	### Test ConfigStruct hashification
	def test_06_ConfigStructToHash
		printTestHeader "Arrow::Config: Hashification of ConfigStructs"
		struct = rval = nil

		struct = Arrow::Config::ConfigStruct::new( TestConfig )
		
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

		assert_nothing_raised { config = Arrow::Config::new }
		assert_instance_of Arrow::Config, config

		Arrow::Config::Defaults.each {|key,val|
			assert_nothing_raised { rval = config.send(key) }
			assert_config_equal val, rval, key
		}

		# Test for delegated methods
		[:to_h, :members, :member?].each {|sym|
			assert_respond_to config, sym
		}
	end


	### Test instantiation of the Config class with configuration values.
	def test_11_InstantiationWithArgs
		printTestHeader "Arrow::Config: Instantiation with arguments"
		rval = config = nil

		assert_nothing_raised {
			config = Arrow::Config::new( TestConfig )
		}
		assert_instance_of Arrow::Config, config

		# The configuration values should be the test config merged with the
		# defaults for the config class.
		(TestConfig.keys|Arrow::Config::Defaults.keys).each {|key|
			val = TestConfig[key] || Arrow::Config::Defaults[key]
			assert_nothing_raised { rval = config.send(key) }
			assert_config_equal val, rval, key
		}
	end


	### Test the abstract Config::Loader class.
	def test_30_Loader
		printTestHeader "Arrow::Config: Loader base class"

# Removed until I figure out the weird doubling bug with AbstractClass [MG]
#		assert_raises( Arrow::InstantiationError ) {
#			Arrow::Config::Loader::new
#		}

		assert_respond_to Arrow::Config::Loader, :create
	end


	### Test the ::create method of Loader with the YAML Loader class.
	def test_31_CreateYamlLoader
		printTestHeader "Arrow::Config: YAML loader"
		loader = rval = nil

		assert_nothing_raised {
			loader = Arrow::Config::Loader::create( 'yaml' )
		}
		assert_kind_of Arrow::Config::Loader, loader

		assert_nothing_raised {
			loader = Arrow::Config::Loader::create( 'YAML' )
		}
		assert_kind_of Arrow::Config::Loader, loader

		assert_nothing_raised {
			loader = Arrow::Config::Loader::create( 'Yaml' )
		}
		assert_kind_of Arrow::Config::Loader, loader
	end


	### Write config
	def test_40_ConfigWriteRead
		printTestHeader "Arrow::Config: #write and #read"
		
		config = Arrow::Config::new( TestConfig )
		assert_nothing_raised {
			config.write( TestConfigFilename )
		}

		otherConfig = Arrow::Config::load( TestConfigFilename )

		assert_config_equal config.struct, otherConfig.struct
	end


	### Changed methods
	def test_50_changed
		printTestHeader "Arrow::Config: #changed? and .item.modified?"
		rval = nil

		config = Arrow::Config::new( TestConfig )
		assert_nothing_raised {
			rval = config.changed?
		}
		assert_equal false, rval

		
	end

end
