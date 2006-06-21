#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Logger class
# $Id$
#
# Copyright (c) 2003, 2005, 2006 RubyCrafters, LLC. Most rights reserved.
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

require 'arrow/logger'


module Arrow

	module LogDelegators
		def debug_log( msg )
			self.log.debug( msg )
		end

		def info_log( msg )
			self.log.info( msg )
		end

		def notice_log( msg )
			self.log.notice( msg )
		end

		def warning_log( msg )
			self.log.warning( msg )
		end

		def error_log( msg )
			self.log.error( msg )
		end

		def crit_log( msg )
			self.log.crit( msg )
		end

		def alert_log( msg )
			self.log.alert( msg )
		end

		def emerg_log( msg )
			self.log.emerg( msg )
		end
	end

	class TestObject < Arrow::Object
		include LogDelegators
	end
	
	class TestObject::SubObject < Arrow::Object
		include LogDelegators
	end


	class TestOutputter < Arrow::Logger::Outputter
		def initialize( name="Testing outputter" )
			@output_calls = []
			@output = ''
			super( name )
		end

		attr_reader :output_calls, :output

		def write( *args )
			@output_calls << args
			super {|msg| @output << msg}
		end

		def clear
			@output_calls.clear
			@output = ''
		end
	end


	### Log tests
	class LogTestCase < Arrow::TestCase

		LogLevels = [ :debug, :info, :notice, :warning, :error, :crit, :alert, :emerg ]

		def teardown
			Arrow::Logger.reset
		end


		#############################################################
		### T E S T S
		#############################################################

		def test_global_logger_method_returns_a_logger
			rval = nil

			assert_nothing_raised do rval = Arrow::Logger.global end
			assert_instance_of Arrow::Logger, rval
			assert_equal "", rval.name
		end


		def test_outputter_attached_to_global_logger_outputs_for_global_messages
			rval = nil

			testOp = TestOutputter.new
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

			testOp = TestOutputter.new
			Arrow::Logger.global.outputters << testOp

			LogLevels.each_with_index do |level, lvl_i|
				Arrow::Logger.global.level = level

				LogLevels.each_with_index do |msglevel, msg_i|
					Arrow::Logger.send( msglevel, "test message" )

					if msg_i < lvl_i
						assert testOp.output_calls.empty?,
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
			testobj = TestObject.new

			assert_nothing_raised do
				rval = testobj.send( :log )
			end

			assert_instance_of Arrow::Logger, rval
			assert_equal "::Arrow::TestObject", rval.name
		end


		def test_outputter_attached_to_global_logger_outputs_for_instance_messages
			testObj = TestObject.new
			testOp = TestOutputter.new

			Arrow::Logger.global.outputters << testOp

			LogLevels.each do |level|
				assert_nothing_raised { Arrow::Logger.global.level = level }

				assert_nothing_raised { testObj.send(:log).send(level, "test message") }
				assert_match( /test message/, testOp.output )
				testOp.clear
			end
		end


		def test_readable_name_should_return_name_derived_from_logged_class
			logger = Arrow::Logger[ TestObject ]
			rval = nil

			assert_nothing_raised do
				rval = logger.readable_name
			end

			assert_equal "Arrow::TestObject", rval
		end


		def test_readable_name_should_return_global_for_global_logger
			logger = Arrow::Logger.global
			rval = nil

			assert_nothing_raised do
				rval = logger.readable_name
			end

			assert_equal "(global)", rval
		end


		def test_readable_level_should_return_the_symbol_for_current_level
			logger = Arrow::Logger[ TestObject ]
			logger.level = :notice
			rval = nil

			assert_nothing_raised do
				rval = logger.readable_level
			end

			assert_equal :notice, rval
		end


		def test_hierloggers_should_return_the_list_of_more_general_loggers
			# Make sure both loggers are created
			logger = Arrow::Logger[ TestObject ] or raise "couldn't create a logger"
			sublogger = Arrow::Logger[ TestObject::SubObject ]
			
			hloggers = nil
			assert_nothing_raised do
				hloggers = sublogger.hierloggers
			end
			
			assert_instance_of Array, hloggers
			assert_equal 4, hloggers.length,
				"expect 4 hierloggers for Arrow::TestObject::SubObject: %p" %
				[ hloggers ]
			assert_include Arrow::Logger[ TestObject::SubObject ], hloggers
			assert_include Arrow::Logger[ TestObject ], hloggers
			assert_include Arrow::Logger[ Arrow ], hloggers
			assert_include Arrow::Logger.global, hloggers
		end


		def test_hierloggers_with_block_should_yield_each_logger
			# Make sure both loggers are created
			logger = Arrow::Logger[ TestObject ]
			sublogger = Arrow::Logger[ TestObject::SubObject ]
			
			hloggers = []
			assert_nothing_raised do
				sublogger.hierloggers do |logger|
					hloggers << logger
				end
			end

			assert_equal 4, hloggers.length,
				"expect 4 hierloggers for Arrow::TestObject::SubObject: %p" %
				[ hloggers ]
			assert_include Arrow::Logger[ TestObject::SubObject ], hloggers
			assert_include Arrow::Logger[ TestObject ], hloggers
			assert_include Arrow::Logger[ Arrow ], hloggers
			assert_include Arrow::Logger.global, hloggers
		end
		

		def test_hieroutputters_should_return_outputters_for_hierloggers
			# Make sure both loggers are created
			logger = Arrow::Logger[ TestObject ]
			sublogger = Arrow::Logger[ TestObject::SubObject ]
			outputter1 = TestOutputter.new( "outputter1" )
			outputter2 = TestOutputter.new( "outputter2" )

			logger.outputters << outputter1
			Arrow::Logger.global.outputters << outputter2
			
			outputters = nil
			assert_nothing_raised do
				outputters = sublogger.hieroutputters
			end
			
			assert_instance_of Array, outputters
			assert_equal 2, outputters.length,
				"expect 2 hieroutputters for Arrow::TestObject::SubObject: %p" %
				[ outputters ]
			assert_include outputter1, outputters
			assert_include outputter2, outputters
		end
	
		def test_hieroutputters_with_block_should_yield_each_outputter
			# Make sure both loggers are created
			logger = Arrow::Logger[ TestObject ]
			sublogger = Arrow::Logger[ TestObject::SubObject ]
			outputter1 = TestOutputter.new( "outputter1" )
			outputter2 = TestOutputter.new( "outputter2" )

			logger.outputters << outputter1
			Arrow::Logger.global.outputters << outputter2
			
			outputters = []
			loggers = []
			assert_nothing_raised do
				sublogger.hieroutputters do |outputter, logger|
					outputters << outputter
					loggers << logger
				end
			end
			
			assert_instance_of Array, outputters
			assert_equal 2, outputters.length,
				"expect 2 hieroutputters for Arrow::TestObject::SubObject: %p" %
				[ outputters ]
			assert_include outputter1, outputters
			assert_include outputter2, outputters	
		end
	
		def test_writing_to_a_sublogger_should_output_to_superlogger_with_lower_or_equal_level
			baselogger = Arrow::Logger[ Arrow ]
			baselogger.level = :debug
			baseoutputter = TestOutputter.new( "base outputter" )
			baselogger.outputters << baseoutputter
			
			superlogger = Arrow::Logger[ TestObject ]
			superlogger.level = :info
			superoutputter = TestOutputter.new( "superlogger outputter" )
			superlogger.outputters << superoutputter
			
			sublogger = Arrow::Logger[ TestObject::SubObject ]
			sublogger.level = :notice
			suboutputter = TestOutputter.new( "sublogger outputter" )
			sublogger.outputters << suboutputter
			
			obj = TestObject::SubObject.new
			
			obj.debug_log  "debug message"
			obj.info_log   "info message"
			obj.notice_log "notice message"
			
			assert_equal 1, suboutputter.output_calls.nitems
			assert_include "notice message", suboutputter.output
			
			assert_equal 2, superoutputter.output_calls.nitems
			assert_include "notice message", superoutputter.output
			assert_include "info message", superoutputter.output
			
			assert_equal 3, baseoutputter.output_calls.nitems
			assert_include "notice message", baseoutputter.output
			assert_include "info message", baseoutputter.output
			assert_include "debug message", baseoutputter.output
		end
		
		def test_messages_should_only_be_output_once_per_outputter
			outputter = TestOutputter.new( "single outputter" )
			
			for klass in [Arrow, Arrow::TestObject, Arrow::TestObject::SubObject]
				Arrow::Logger[ klass ].level = :debug
				Arrow::Logger[ klass ].outputters << outputter
			end

			Arrow::Logger.global.level = :debug
			Arrow::Logger.global.outputters << outputter

			Arrow::TestObject::SubObject.new.debug_log "message"
			
			assert_equal 1, outputter.output_calls.nitems
		end
		
		def test_logging_an_exception_should_include_its_backtrace
			outputter = TestOutputter.new
			Arrow::Logger.global.outputters << outputter

			obj = TestObject.new

			begin
				throw "Glah."
			rescue => err
				obj.error_log( err )
			end

			assert_include self.name.sub( /\(.*/, '' ), outputter.output
		end


		def test_parse_log_setting_should_just_return_level_if_its_a_single_word
			level = uri = nil
			
			assert_nothing_raised do
				level, uri = Arrow::Logger.parse_log_setting( "debug" )
			end
			
			assert_equal :debug, level
			assert_equal nil, uri
		end
		
		
		def test_parse_log_setting_should_return_a_uri_if_setting_has_two_words
			level = uri = nil
			
			assert_nothing_raised do
				level, uri = Arrow::Logger.parse_log_setting( "info apache" )
			end
			
			assert_equal :info, level
			assert_kind_of URI::Generic, uri
		end
		
		def test_parse_log_setting_should_return_a_uri_if_setting_includes_complex_uri
			level = uri = nil
			complexuri = 'dbi://www:password@localhost/www.errorlog?driver=postgresql'
			
			assert_nothing_raised do
				level, uri = Arrow::Logger.parse_log_setting( "error #{complexuri}" )
			end
			
			assert_equal :error, level
			assert_kind_of URI::Generic, uri
		end

		def test_configure_should_use_apache_log_outputter_if_none_specified
			Arrow::Logger.configure( {:global => 'debug'}, nil )

			assert_instance_of Arrow::Logger::ApacheOutputter,
				Arrow::Logger.global.outputters.first
			assert_equal :debug, Arrow::Logger.global.readable_level
		end
		
		def test_configure_with_file_uri_should_use_fileouputter
			Arrow::Logger.configure( {:global => 'error file:stderr'}, nil )
			
			assert_instance_of Arrow::Logger::FileOutputter,
				Arrow::Logger.global.outputters.first
			assert_equal :error, Arrow::Logger.global.readable_level
		end
		
		def test_configure_with_simple_class_name_should_prepend_arrow_namespace
			Arrow::Logger.configure( {:applet => 'notice file:stderr'}, nil )
			
			assert_instance_of Arrow::Logger::FileOutputter,
				Arrow::Logger[Arrow::Applet].outputters.first
			assert_equal :notice, Arrow::Logger[Arrow::Applet].readable_level
		end

		def test_configure_with_full_class_name_should_create_a_logger_for_that_class
			Arrow::Logger.configure( {:"Arrow::Applet" => 'info file:stderr'}, nil )
			
			assert_instance_of Arrow::Logger::FileOutputter,
				Arrow::Logger[Arrow::Applet].outputters.first
			assert_equal :info, Arrow::Logger[Arrow::Applet].readable_level
		end
		
		def test_configure_with_full_class_name_should_create_a_logger_for_non_arrow_class
			Arrow::Logger.configure( {:"String" => 'warning file:stderr'}, nil )
			
			assert_instance_of Arrow::Logger::FileOutputter,
				Arrow::Logger[String].outputters.first
			assert_equal :warning, Arrow::Logger[String].readable_level
		end
		
	end # class LogTestCase
end # module Arrow


