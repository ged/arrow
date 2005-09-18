#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Logger class
# $Id$
#
# Copyright (c) 2003, 2005 RubyCrafters, LLC. Most rights reserved.
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
			@outputCalls.clear
			@output = ''
		end
	end


	### Log tests
	class LogTestCase < Arrow::TestCase

		LogLevels = [ :debug, :info, :notice, :warning, :error, :crit, :alert, :emerg ]

		def teardown
			Arrow::Logger.global.outputters.clear
		end


		#############################################################
		###	T E S T S
		#############################################################

		def test_logger_class_is_loaded
			assert_instance_of Class, Arrow::Logger
			[ :[], :global, :method_missing ].each {|sym|
				assert_respond_to Arrow::Logger, sym
			}
		end

		def test_global_logger_method_returns_a_logger
			rval = nil

			assert_nothing_raised { rval = Arrow::Logger.global }
			assert_instance_of Arrow::Logger, rval
			assert_equal "", rval.name
		end


		def test_outputter_attached_to_global_logger_outputs_for_global_messages
			rval = nil

			testOp = TestOutputter::new
			assert_nothing_raised do
				Arrow::Logger.global.outputters << testOp
			end

			# Try outputting at each logging level
			LogLevels.each do |level|
				assert_nothing_raised { Arrow::Logger.global.level = level }
				assert_nothing_raised { Arrow::Logger.send(level, "test message") }
				assert_match( /test message/, testOp.output, "for output on #{level}" )
			end
		end


		def test_messages_to_global_logger_heed_global_loggers_level
			rval = nil

			testOp = TestOutputter::new
			Arrow::Logger.global.outputters << testOp

			LogLevels.each_with_index do |level, lvl_i|
				Arrow::Logger.global.level = level

				LogLevels.each_with_index do |msglevel, msg_i|
					Arrow::Logger.send( msglevel, "test message" )

					if msg_i < lvl_i
						assert testOp.outputCalls.empty?,
							"Expected no output calls for a %p message at %p level" %
							[ msglevel, level ]
					else
						assert_match( /test message/, testOp.output,
							"for %p output at %p" % [msglevel, level] )
					end

					testOp.clear
				end
			end
		end

		def test_arrow_objects_return_their_logger_object
			rval = nil
			testobj = TestObject::new

			assert_nothing_raised do
				rval = testobj.send( :log )
			end

			assert_instance_of Arrow::Logger, rval
			assert_equal "::Arrow::TestObject", rval.name
		end


		def test_outputter_attached_to_global_logger_outputs_for_instance_messages
			testObj = TestObject::new
			testOp = TestOutputter::new

			Arrow::Logger.global.outputters << testOp

			LogLevels.each do |level|
				assert_nothing_raised { Arrow::Logger.global.level = level }

				assert_nothing_raised { testObj.send(:log).send(level, "test message") }
				assert_match( /test message/, testOp.output )
				testOp.clear
			end
		end


	end
end


