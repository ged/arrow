#!/usr/bin/ruby

# 
# Some helper functions for RSpec specifications
# 
# 

require 'arrow/logger/htmloutputter'

### A module of miscellaneous stuff that makes running RSpec a little nicer
module Arrow::SpecHelpers

	# The default logging level for reset_logging/setup_logging
	DEFAULT_LOG_LEVEL = :crit

	### Remove any outputters and reset the level to DEFAULT_LOG_LEVEL
	def reset_logging
		Arrow::Logger.reset
	end

	### Set up an HTML log outputter at the specified +level+ that's been tailored to SpecMate 
	### output.
	def setup_logging( level=DEFAULT_LOG_LEVEL )
		reset_logging()
		description = "`%s' spec" % [ @_defined_description ]

		# Only do this when executing from a spec in TextMate
		if ENV['HTML_LOGGING'] || (ENV['TM_FILENAME'] && ENV['TM_FILENAME'] =~ /_spec\.rb/)
			outputter = Arrow::Logger::Outputter.create( 'array' )
			Thread.current['logger-output'] = outputter.array
		else
			outputter = Arrow::Logger::Outputter.create( 'color:stderr', description )
		end

		Arrow::Logger.global.outputters << outputter
		Arrow::Logger::global.level = level
	end

end

