#!/usr/bin/ruby -w
#
# Unit test for the Arrow::RubyTokenParser class
# $Id: 07_rubytokenparser.tests.rb,v 1.1 2004/01/09 03:14:54 deveiant Exp $
#
# Copyright (c) 2004 RubyCrafters, LLC. Most rights reserved.
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

require 'arrow/rubytokenreactor'

### Collection of tests for the Arrow::RubyTokenParser class.
class Arrow::RubyTokenParserTestCase < Arrow::TestCase

	TestCode = "'a string'.length"
	TestTokens = [
		[:on__tstring_beg, "'"],
		[:on__tstring_content, "a string"],
		[:on__tstring_end, "'"],
		[:on__period, "."],
		[:on__ident, "length"]
	]

	TestMatrix = [

		# :on__var_ref
		[
			"Var reference",
			"obj.methods.include?( :inspect )",
			[ :var_ref ],
			[ [:obj] ]
		],

	]

	# Where to start numbering the auto-generated tests
	AutoOffset = 50

	# Auto-generate reactor tests
	TestMatrix.each_with_index {|test, i|
		name, code, events, values = *test

		methname = "test_%03d_%s" %
			[ i + AutoOffset, name.downcase.gsub(/[^\w]+/, '_') ]

		code = <<-EOCODE
		def #{methname}
			printTestHeader "RubyTokenReactor: Parsing: #{name}"
			tr = nil
			values = []

			assert_nothing_raised {
				tr = Arrow::RubyTokenReactor::new(#{code.inspect})
			}
			assert_nothing_raised {
				tr.onEvents( *#{events.inspect} ) {|reactor, *args|
					values << args
				}
				tr.parse
			}

			assert_equal #{values.inspect}, values
		end
		EOCODE

		debugMsg "Autogenerated #{methname}: \n#{code}"
		eval code
	}


	#################################################################
	###	T E S T S
	#################################################################

	### Instance test
	def test_00_instantiate
		printTestHeader "RubyTokenReactor: instantiate"
		tr = nil

		assert defined?( Arrow::RubyTokenReactor ),
			"Arrow::RubyTokenReactor not defined"
		assert_instance_of Class, Arrow::RubyTokenReactor
		assert_nothing_raised {
			tr = Arrow::RubyTokenReactor::new( TestCode, "TestCode", 1 )
		}
		assert_instance_of Arrow::RubyTokenReactor, tr

		addSetupBlock {
			@tr = Arrow::RubyTokenReactor::new( TestCode, "TestCode", 1 )
		}
		addTeardownBlock {
			@tr = nil
		}
	end

	### Parse test
	def test_10_parse
		printTestHeader "RubyTokenReactor: parse"

		assert_respond_to @tr, :parse
		assert_nothing_raised {
			@tr.parse
		}
	end

	### Event registration tests
	def test_20_onEvents
		printTestHeader "RubyTokenReactor: onEvents"
		vals = []
		calls = 0
		cb = lambda {|*args| vals << args; calls += 1}

		assert_respond_to @tr, :onEvents
		assert_nothing_raised {
			@tr.onEvents( :scan, &cb )
			@tr.parse
		}

		assert_equal 5, calls, "Number of calls to the callback"
		debugMsg "vals = %p" % [ vals ]
	end
	
end

