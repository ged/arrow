#!/usr/bin/env ruby

require 'logger'

module Apache

	# An adapter object that can be used as a log device for a Logger instance that
	# sends log messages to Apache's logging subsystem at 'debug' level.
	class LogDevice < Logger::LogDevice

		def initialize( *args ); end

		### Write a logging message to Apache's debug log.
		def write( message )
			Apache.request.server.log_debug( message )
		end

		### No-op -- this is here just so Logger doesn't complain
		def close; end

	end # class LogDevice

	# A formatter for log messages that will be forwarded into Apache's log system.
	class LogFormatter < Logger::Formatter

		def call( severity, time, progname, msg )
			return "[%s] %s: %s" % [ severity, progname, msg ]
		end

	end

end # module Apache

