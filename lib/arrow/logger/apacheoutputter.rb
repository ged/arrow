#!/usr/bin/env ruby

require 'arrow/mixins'
require 'arrow/logger'
require 'arrow/logger/outputter'

# The Arrow::Logger::ApacheOutputter class, a derivative of
# Apache::Logger::Outputter. Instances of this class write log messages of the
# corresponding error level to the Apache log
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Logger::ApacheOutputter < Arrow::Logger::Outputter

	# The default description
	DefaultDescription = "Apache Log Outputter"

	# The default interpolatable string that's used to build the message to
	# output
	DefaultFormat =
		%q{#{name}#{frame ? '('+frame+')' : ''}: #{msg[0,2048]}}

	# The Logger log levels (copied for easy access)
	LEVELS = Arrow::Logger::LEVELS


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Logger::ApacheOutputter object that will write
	### to the apache log, and use the given +description+ and +format+.
	def initialize( uri, description=DefaultDescription, format=DefaultFormat )
		super
	end


	######
	public
	######

	### Write the given +level+, +name+, +frame+, and +msg+ to the target
	### output mechanism.
	def write( time, level, name, frame, msg )
		return unless defined?( ::Apache )
		srvr = ::Apache.request.server
		return unless srvr.loglevel >= LEVELS[ level ]

		# Translate calls to log.warning into Apache::Server#log_warn
		level = :warn if level == :warning

		logMethod = srvr.method( "log_#{level}" )
		super {|msg|
			# Escape any unexpanded sprintf format patterns
			msg.gsub!( /%/, '%%' )
			logMethod.call( msg )
		}
	end


end # class Arrow::Logger::ApacheOutputter




