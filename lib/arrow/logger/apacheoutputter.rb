#!/usr/bin/env ruby
# 
# This file contains the Arrow::Logger::ApacheOutputter class, a derivative of
# Apache::Logger::Outputter. Instances of this class write log messages of the
# corresponding error level to the Apache log
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
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'arrow/mixins'
require 'arrow/logger'
require 'arrow/logger/outputter'

### Instances of this class write log messages of the corresponding error
### level to the Apache log.
class Arrow::Logger::ApacheOutputter < Arrow::Logger::Outputter

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The default description
	DefaultDescription = "Apache Log Outputter"

	# The default interpolatable string that's used to build the message to
	# output
	DefaultFormat =
		%q{#{name}#{frame ? '('+frame+')' : ''}: #{msg[0,2048]}}

	# The Logger log levels (copied for easy access)
	Levels = Arrow::Logger::Levels


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
		return unless srvr.loglevel >= Levels[ level ]

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




