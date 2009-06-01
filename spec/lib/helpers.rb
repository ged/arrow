#!/usr/bin/ruby

# 
# Some helper functions for RSpec specifications
# 
# 


### A module of miscellaneous stuff that makes running RSpec a little nicer
module Arrow::SpecHelpers

	class ArrayLogOutputter < Arrow::Logger::Outputter

		FORMAT = %q{
		<dd class="log-message #{level}">
			<span class="log-time">#{time.strftime('%Y/%m/%d %H:%M:%S')}</span>
			<span class="log-level">#{level}</span>
			:
			<span class="log-name">#{escaped_name}</span>
			<span class="log-frame">#{frame ? '('+frame+'): ' : ''}</span>
			<span class="log-message-text">#{escaped_msg}</span>
		</dd>
		}

		### Create a new ArrayLogOutputter that will append content to +array+.
		def initialize( array )
			super( 'arraylogger', 'Array Logger', FORMAT )
			@array = array
		end
		
		attr_accessor :array
		
		### Write the specified +message+ to the array.
		def write( *args )
			super {|msg| @array << msg }
		end
		
	end # class ArrayLogger


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
		outputter = nil

		# Only do this when executing from a spec in TextMate
		if ENV['HTML_LOGGING'] || (ENV['TM_FILENAME'] && ENV['TM_FILENAME'] =~ /_spec\.rb/)
			Thread.current['logger-output'] = []
			outputter = ArrayLogOutputter.new( Thread.current['logger-output'] )
		else
			outputter = Arrow::Logger::Outputter.create( 'color:stderr', description )
		end

		Arrow::Logger.global.outputters << outputter
		Arrow::Logger::global.level = level
	end

end


