#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Logger class
# $Id: 10_logger.tests.rb,v 1.1 2003/12/02 06:09:31 deveiant Exp $
#
# Copyright (c) 2003 RubyCrafters, LLC. Most rights reserved.
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

require 'arrow/logger'


module Arrow

	class TestObject < Arrow::Object
		def debugLog( msg )
			self.log.debug( msg )
		end

		def infoLog( msg )
			self.log.info( msg )
		end

		def noticeLog( msg )
			self.log.notice( msg )
		end

		def warningLog( msg )
			self.log.warning( msg )
		end

		def errorLog( msg )
			self.log.error( msg )
		end

		def critLog( msg )
			self.log.crit( msg )
		end

		def alertLog( msg )
			self.log.alert( msg )
		end

		def emergLog( msg )
			self.log.emerg( msg )
		end
	end


	class TestOutputter < Arrow::Logger::Outputter
		def initialize
			@outputCalls = []
			@output = ''
			super( "Testing outputter" )
		end

		attr_reader :outputCalls, :output

		def write( *args )
			@outputCalls << args
			super {|msg| @output << msg}
		end

		def clear
			@outputCalls = []
			@output = ''
		end
	end


	### Log tests
	class LogTestCase < Arrow::TestCase

		LogLevels = [ :debug, :info, :notice, :warning, :error, :crit, :alert, :emerg ]

		def test_00_Loaded
			printTestHeader "Logger: Classes loaded"

			assert_instance_of Class, Arrow::Logger
			[ :[], :global, :method_missing ].each {|sym|
				assert_respond_to Arrow::Logger, sym
			}
		end

		def test_10_GlobalLogMethods
			printTestHeader "Logger: Global log methods"
			rval = nil
			testOp = TestOutputter::new

			assert_nothing_raised { rval = Arrow::Logger.global }
			assert_instance_of Arrow::Logger, rval
			assert_equal "", rval.name

			Arrow::Logger.global.outputters << testOp

			LogLevels.each {|level|
				assert_nothing_raised { Arrow::Logger.global.level = level }
				assert_nothing_raised { Arrow::Logger.send(level, "test message") }
				assert_match( /test message/, testOp.output, "for output on #{level}" )

				testOp.clear

				unless level == :emerg
					assert_nothing_raised { Arrow::Logger.global.level = :emerg }
					Arrow::Logger.send(level, "test message")
					assert testOp.output.empty?, "Outputter expected to be empty"
				end
			}
		end

		def test_20_MuesObjectLogMethods
			printTestHeader "Logger: Object log methods"

			testObj = TestObject::new
			testOp = TestOutputter::new

			Arrow::Logger.global.outputters = [ testOp ]

			LogLevels.each {|level|
				assert_nothing_raised { Arrow::Logger.global.level = level }
				meth = "#{level.to_s}Log".intern
				assert_nothing_raised { testObj.send(meth, "test message") }
				assert_match( /test message/, testOp.output )
				testOp.clear
			}
		end


	end
end


