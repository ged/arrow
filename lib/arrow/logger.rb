#!/usr/bin/ruby
#
# This file contains the Arrow::Logger class, a hierarchical logging class for
# the Arrow framework. It provides a generalized means of logging from inside
# Arrow classes, and then selectively outputting/formatting log messages from
# points within the hierarchy.
#
# A lot of concepts in this class were stolen from Log4r, though it's all
# original code, and works a bit differently.
# 
# == Synopsis
# 
#   require 'arrow/object'
#   require 'arrow/logger'
# 
#   logger = Arrow::Logger::global
#	logfile = File::open( "global.log", "a" )
#	logger.outputters += Arrow::Logger::Outputter::new(logfile)
#	logger.level = :debug
#
#	class MyClass < Arrow::Object
#
#		def self::fooMethod
#			Arrow::Logger.debug( "In server start routine" )
#			Arrow::Logger.info( "Server is not yet configured." )
#			Arrow::Logger.notice( "Server is starting up." )
#		end
#
#		def initialize
#			self.log.info( "Initializing another MyClass object." )
#		end
#	end
#
# == Rcsid
# 
# $Id: logger.rb,v 1.5 2003/12/02 07:12:19 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require 'arrow/utils'

module Arrow

	### A log class for Arrow systems.
	class Logger

		require 'arrow/logger/outputter'

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.5 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: logger.rb,v 1.5 2003/12/02 07:12:19 deveiant Exp $

		# Log levels array (in order of decreasing verbosity)
		Levels = [
			:debug,
			:info,
			:notice,
			:warning,
			:error,
			:crit,
			:alert,
			:emerg,
		].inject({}) {|hsh, sym| hsh[ sym ] = hsh.length; hsh}

		# Constant for debugging the logger - set to true to output internals to
		# $stderr.
		DebugLogger = false


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		@loggers = {}

		class << self
			# The hierarchy of all Arrow::Logger objects.
			attr_reader :loggers
		end


		### Return the Arrow::Logger for the given module +mod+, which can be a
		### Module object, a Symbol, or a String.
		def self::[]( mod=nil )
			modname = mod.to_s
			return self::global if modname.empty?

			modname = '::' + modname unless /^::/ =~ modname
			names = modname.split( /::/ )

			# Create the global logger if it isn't already created
			@loggers[ '' ] ||= new( '' )

			names.inject( @loggers ) {|logger,key| logger[key]}
		end


		### Return the global Arrow logger, setting it up if it hasn't been
		### already.
 		def self::global
			@loggers[ '' ] ||= new( '' )
		end


		### Autoload global logging methods for the log levels
		def self::method_missing( sym, *args )
			return super unless Levels.key?( sym )

			self.global.debug( "Autoloading class log method '#{sym}'." )
			(class << self; self; end).class_eval {
				define_method( sym ) {|*args|
					self.global.send( sym, *args )
				}
			}

			self.global.send( sym, *args )
		end


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create and return a new Arrow::Logger object with the given +name+
		### at the specified +level+, with the specified +superlogger+. Any
		### +outputters+ that are specified will be added.
		def initialize( name, level=:info, superlogger=nil, *outputters )
			if name.empty?
				debugMsg "Creating global logger"
			else
				debugMsg "Creating logger for #{name}"
			end
			
			@name = name
			@outputters = outputters
			@subloggers = {}
			@superlogger = superlogger
			@trace = false
			@level = nil

			self.level = level
		end


		######
		public
		######

		# The name of this logger
		attr_reader :name

		# The outputters attached to this branch of the logger tree.
		attr_accessor :outputters

		# The logger object that is this logger's parent (if any).
		attr_reader :superlogger

		# The branches of the logging hierarchy that fall below this one.
		attr_accessor :subloggers

		# Set to a true value to turn tracing on
		attr_accessor :trace

		# The integer level of the logger.
		attr_reader :level


		### Return the name of the logger formatted to be suitable for reading.
		def readableName
			logname = self.name.sub( /^::/, '' )
			logname = '(global)' if logname.empty?

			return logname
		end


		### Set the level of this logger to +level+. The +level+ can be a
		### String, a Symbol, or an Integer.
		def level=( level )
			case level
			when String
				@level = Levels[ level.intern ]
			when Symbol
				@level = Levels[ level ]
			when Integer
				@level = level
			else
				raise ArgumentError, "Illegal level specification: %s" %
					level.class.name
			end
		end


		### Return the level of this logger as a Symbol
		def levelSym
			Levels.invert[ @level ]
		end


		### Return a uniquified Array of the loggers which are more-generally
		### related hierarchically to the receiver, inclusive.
		def hierloggers( level=0 )
			level = Levels[ level ] if level.is_a?( Symbol )
			loggers = []
			logger = self
			lastlogger = nil

			debugMsg "Searching for loggers in the hierarchy whose level <= %p" % level

			begin
				lastlogger = logger
				if logger.level <= level
					debugMsg "hierloggers: added %s" % logger.readableName
					loggers.push( logger )
					yield( logger ) if block_given?
				else
					debugMsg "hierloggers: discarding %s (%p)" %
						[ logger.readableName, logger.levelSym ]
				end
			end while (( logger = lastlogger.superlogger ))

			return loggers
		end


		### Return a uniquified Array of all outputters for this logger and all
		### of the loggers above it in the logging hierarchy.
		def hieroutputters( level=0 )
			outputters = []
			level = Levels[ level ] if level.is_a?( Symbol )

			self.hierloggers( level ) {|logger|
				outpary = logger.outputters
				newoutpary = outpary - (outpary & outputters)
				unless newoutpary.empty?
					debugMsg "hieroutputters: adding: %s" %
						newoutpary.collect {|outp| outp.description}.join(", ")
					if block_given?
						newoutpary.each {|outputter| yield(outputter)}
					end
					outputters += newoutpary
				end
			}

			return outputters
		end


		### Write the given +args+ to any connected outputters if +level+ is
		### less than or equal to this logger's level. If the first item in
		### +args+ is a String and contains %<char> codes, the message will
		### formed by using the first argument as a format string in +sprintf+
		### with the remaining items. Otherwise, the message will be formed by
		### catenating the results of calling #formatObject on each of them.
		def write( level, *args )
			debugMsg "Writing message at %p: %p" % [ level, args ]
				
			msg, frame = nil, nil
			time = Time::now

			# If tracing is turned on, pick the first frame in the stack that
			# isn't in this file, or the last one if that fails to yield one.
			if @trace
				re = Regexp::new( Regexp::quote(__FILE__) + ":\d+:" )
				frame = caller(1).find {|fr| re !~ fr} || caller(1).last
			end

			self.hieroutputters( level ) {|outp|
				debugMsg "Got outputter %p" % outp
				msg ||= args.collect {|obj| self.stringifyObject(obj)}.join
				outp.write( time, level, self.readableName, frame, msg )
			}
		end


		### Return the sublogger for the given module +mod+ (a Module, a String,
		### or a Symbol) under this logger. A new one will instantiated if it
		### does not already exist.
		def []( mod )
			@subloggers[ mod.to_s ] ||=
				self.class.new( @name + "::" + mod.to_s, self.level, self )
		end


		#########
		protected
		#########

		### Dump the given object for output in the log.
		def stringifyObject( obj )
			return case obj
				   when Exception
					   "%s:\n    %s" % [ obj.message, obj.backtrace("\n    ") ]
				   when String
					   obj
				   else
					   obj.inspect
				   end
		end


		### Auto-install logging methods (ie., methods whose names match one of
		### Arrow::Logger::Levels.
		def method_missing( id, *args )
			super unless Arrow::Logger::Levels.member?( id )

			debugMsg "Autoloading instance log method '#{id}'"
			self.class.class_eval {
				define_method( id ) {|*args| self.write(id, *args)}
			}

			self.send( id, *args )
		end


		#######
		private
		#######

		### Output a debugging message if DebugLogger is true.
		if DebugLogger
			def debugMsg( *parts ) # :nodoc:
				$stderr.puts parts.join('')
			end
		else
			def debugMsg( *parts ); end # :nodoc:
		end



	end # class Logger

end #module Arrow

