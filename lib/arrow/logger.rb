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
#   logger = Arrow::Logger.global
#	logfile = File.open( "global.log", "a" )
#	logger.outputters << Arrow::Logger::Outputter.new(logfile)
#	logger.level = :debug
#
#	class MyClass < Arrow::Object
#
#		def self.fooMethod
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
# == Subversion Id
#
#  $Id$
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
require 'arrow/mixins'

### A log class for Arrow systems.
class Arrow::Logger
	require 'arrow/logger/outputter'

    include Arrow::Configurable
    config_key :logging


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Construct a log levels Hash on the fly
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
	LevelNames = Levels.invert

	# Constant for debugging the logger - set to true to output internals to
	# $stderr.
	module DebugLogger
		def debug_msg( *parts ) # :nodoc:
			#$deferr.puts parts.join('') if $DEBUG
		end
	end

	include DebugLogger
	extend DebugLogger



	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	@global_logger = nil

    ### Configure logging from the 'logging' section of the config.
    def self::configure( config, dispatcher )

		self.reset
		apacheoutputter = Arrow::Logger::Outputter.create( 'apache' )

		config.each do |klass, setting|
			level, uri = self.parse_log_setting( setting )

			# Use the Apache log as the outputter if none is configured
			if uri.nil?
				outputter = apacheoutputter
			else
				outputter = Arrow::Logger::Outputter.create( uri )
			end

			# The 'global' entry configured the global logger
			if klass == :global
				self.global.level = level
				self.global.outputters << outputter
				next
			end

			# If the class bit is something like 'applet', then transform
			# it into 'Arrow::Applet'
			if klass.to_s.match( /^[a-z][a-zA-Z]+$/ )
				realclass = "Arrow::%s" % klass.to_s.sub(/^([a-z])/){ $1.upcase }
			else
				realclass = klass.to_s
			end

			# 
			Apache.request.server.log_info \
				"Setting log level for %p to %p" % [realclass, level]
			Arrow::Logger[ realclass ].level = level
			Arrow::Logger[ realclass ].outputters << outputter
		end
		
    end


	### Parse the configuration for a given class's logger. The configuration
	### is in the form:
	###   <level> [<outputter_uri>]
	### where +level+ is one of the logging levels defined by this class (see
	### the Levels constant), and the optional +outputter_uri+ indicates which
	### outputter to use, and how it should be configured. See 
	### Arrow::Logger::Outputter for more info.
	###
	### Examples:
	###   notice
	###   debug file:///tmp/broker-debug.log
	###   error dbi://www:password@localhost/www.errorlog?driver=postgresql
	###
	def self::parse_log_setting( setting )
		level, rawuri = setting.split( ' ', 2 )
		uri = rawuri.nil? ? nil : URI.parse( rawuri )
		
		return level.to_sym, uri
	end
	

	### Return the Arrow::Logger for the given module +mod+, which can be a
	### Module object, a Symbol, or a String.
	def self::[]( mod=nil )
		modname = mod.to_s
		return self.global if modname.empty?

		names = modname.split( /::/ )

		# Create the global logger if it isn't already created
		self.global

		names.inject( @global_logger ) {|logger,key| logger[key]}
	end


	### Return the global Arrow logger, setting it up if it hasn't been
	### already.
	def self::global
		# debug_msg "Creating the global logger" unless @global_logger
		@global_logger ||= new( '' )
	end


	### Reset the logging subsystem. Clears out any registered loggers and 
	### their associated outputters.
	def self::reset
		# debug_msg "Resetting the global logger"
		@global_logger = nil
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
			# debug_msg "Creating global logger"
		else
			# debug_msg "Creating logger for #{name}"
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


	### Return a human-readable string representation of the object.
	def inspect
		"#<%s:0x%0x %s [level: %s, outputters: %d, trace: %s]>" % [
			self.class.name,
			self.object_id * 2,
			self.readable_name,
			self.readable_level,
			self.outputters.length,
			self.trace ? "on" : "off",
		]
	end
	

	### Return the name of the logger formatted to be suitable for reading.
	def readable_name
		logname = self.name.sub( /^::/, '' )
		logname = '(global)' if logname.empty?

		return logname
	end
	

	### Return the logger's level as a Symbol.
	def readable_level
		return LevelNames[ @level ]
	end
	

	### Set the level of this logger to +level+. The +level+ can be a
	### String, a Symbol, or an Integer.
	def level=( level )
		# debug_msg ">>> Setting log level for %s to %p" %
			# [ self.name.empty? ? "[Global]" : self.name, level ]

		case level
		when String
			@level = Levels[ level.intern ]
		when Symbol
			@level = Levels[ level ]
		when Integer
			@level = level
		else
			@level = nil
		end

		# If the level wasn't set correctly, raise an error after setting
		# the level to something reasonable.
		if @level.nil?
			@level = Levels[ :notice ]
			raise ArgumentError, "Illegal log level specification: %p for %s" %
				[ level, self.name ]
		end
	end



	### Return a uniquified Array of the loggers which are more-generally
	### related hierarchically to the receiver, inclusive. If called with a
	### block, it will be called once for each Logger object. If +level+ is
	### specified, only those loggers whose level is +level+ or lower will be
	### selected.
	def hierloggers( level=Levels[:emerg] )
		loggers = []
		logger = self
		lastlogger = nil
		level = Levels[ level ] if level.is_a?( Symbol )

		# debug_msg "Searching for loggers in the hierarchy above %s" % 
			# [ logger.name.empty? ? "[Global]" : logger.name ]

		# Traverse the logger hierarchy upward (more general), looking for ones
		# whose level is below the argument.
		begin
			lastlogger = logger
			next unless logger.level <= level

			# When one is found, add it to the ones being returned and yield it
			# if there's a block
			# debug_msg "hierloggers: added %s" % logger.readable_name
			loggers.push( logger )
			yield( logger ) if block_given?

		end while (( logger = lastlogger.superlogger ))

		return loggers
	end


	### Return a uniquified Array of all outputters for this logger and all of
	### the loggers above it in the logging hierarchy. If called with a block,
	### it will be called once for each outputter and the first logger to which
	### it is attached.
	def hieroutputters( level=Levels[:emerg] )
		outputters = []

		# Look for loggers which are higher in the hierarchy
		self.hierloggers( level ) do |logger|
			outpary = logger.outputters || []
			newoutpary = outpary - (outpary & outputters)

			# If there are any outputters which haven't already been seen,
			# output to them.
			unless newoutpary.empty?
				# debug_msg "hieroutputters: adding: %s" %
					# newoutpary.collect {|outp| outp.description}.join(", ")
				if block_given?
					newoutpary.each {|outputter| yield(outputter, logger)}
				end
				outputters += newoutpary
			end
		end

		return outputters
	end


	### Write the given +args+ to any connected outputters if +level+ is
	### less than or equal to this logger's level. If the first item in
	### +args+ is a String and contains %<char> codes, the message will
	### formed by using the first argument as a format string in +sprintf+
	### with the remaining items. Otherwise, the message will be formed by
	### catenating the results of calling #formatObject on each of them.
	def write( level, *args )
		debug_msg "Writing message at %p: %p" % [ level, args ]

		msg, frame = nil, nil
		time = Time.now

		# If tracing is turned on, pick the first frame in the stack that
		# isn't in this file, or the last one if that fails to yield one.
		if @trace
			frame = caller(1).find {|fr| fr !~ %r{arrow/logger\.rb} } ||
			 	caller(1).last
		end

		# Find the outputters that need to be written to, then write to them.
		self.hieroutputters( level ) do |outp, logger|
			debug_msg "Got outputter %p" % outp
			msg ||= args.collect {|obj| self.stringify_object(obj)}.join
			outp.write( time, level, self.readable_name, frame, msg )
		end
	end


	### Return the sublogger for the given module +mod+ (a Module, a String,
	### or a Symbol) under this logger. A new one will instantiated if it
	### does not already exist.
	def []( mod )
		# debug_msg "creating sublogger for '#{mod}'" unless @subloggers.key?( mod.to_s )
		@subloggers[ mod.to_s ] ||=
			self.class.new( @name + "::" + mod.to_s, self.level, self )
	end


	### Append the given +obj+ to the logger at +:debug+ level. This is for 
	### compatibility with objects that append to $stderr for their logging
	### (e.g., net/protocols-based libraries).
	def <<( obj )
		self.write( :debug, obj )
		return self
	end
	

	#########
	protected
	#########

	### Dump the given object for output in the log.
	def stringify_object( obj )
		return case obj
			   when Exception
				   "%s:\n    %s" % [ obj.message, obj.backtrace.join("\n    ") ]
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

		# debug_msg "Autoloading instance log method '#{id}'"
		self.class.class_eval {
			define_method( id ) {|*args| self.write(id, *args)}
		}

		self.send( id, *args )
	end

end # class Arrow::Logger

