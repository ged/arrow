#!/usr/bin/ruby
# 
# This file contains the Arrow::Logger::ApacheOutputter class, a derivative of
# Apache::Logger::Outputter. Instances of this class write log messages of the
# corresponding error level to the Apache log
# 
# == Rcsid
# 
# $Id: apacheoutputter.rb,v 1.1 2003/10/13 04:20:13 deveiant Exp $
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

module Arrow
class Logger

	### Instances of this class write log messages of the corresponding error
	### level to the Apache log.
	class ApacheOutputter < Arrow::Logger::Outputter

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: apacheoutputter.rb,v 1.1 2003/10/13 04:20:13 deveiant Exp $

		# The default description
		DefaultDescription = "Apache Log Outputter"

		# The default interpolatable string that's used to build the message to
		# output
		DefaultFormat =
			%q{#{name} #{frame ? '('+frame+')' : ''}: #{msg[0,1024]}}

		# The Logger log levels (copied for easy access)
		Levels = Arrow::Logger::Levels


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new Arrow::Logger::ApacheOutputter object that will write
		### to the apache log, and use the given +description+ and +format+.
		def initialize( description=DefaultDescription, format=DefaultFormat )
			super
		end


		######
		public
		######

		### Write the given +level+, +name+, +frame+, and +msg+ to the target
		### output mechanism.
		def write( time, level, name, frame, msg )
			srvr = Apache.request.server
			return unless srvr.loglevel >= Levels[ level ]

			logMethod = srvr.method( "log_#{level}" )
			super {|msg|
				# Escape any unexpanded sprintf format patterns
				msg.gsub!( /%/, '%%' )
				logMethod.call( msg )
			}
		end
		

		#########
		protected
		#########

	end # class ApacheOutputter

end # class Logger
end # module Arrow


