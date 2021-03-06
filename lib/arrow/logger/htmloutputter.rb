#!/usr/bin/env ruby

require 'arrow/mixins'
require 'arrow/logger/fileoutputter'

# Output logging messages in HTML fragments with classes that match their level. 
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Logger::HtmlOutputter < Arrow::Logger::FileOutputter
	include Arrow::HTMLUtilities

	# Default decription used when creating instances
	DEFAULT_DESCRIPTION = "HTML Fragment Logging Outputter"

	# The default logging output format
	HTML_FORMAT = %q{
	<div class="log-message #{level}">
		<span class="log-time">#{time.strftime('%Y/%m/%d %H:%M:%S')}</span>
		<span class="log-level">#{level}</span>
		:
		<span class="log-name">#{escaped_name}</span>
		<span class="log-frame">#{frame ? '('+frame+'): ' : ''}</span>
		<span class="log-message-text">#{escaped_msg}</span>
	</div>
	}


	### Override the default argument values.
	def initialize( uri, description=DEFAULT_DESCRIPTION, format=HTML_FORMAT ) # :notnew:
		super
	end


	### Write the given +level+, +name+, +frame+, and +msg+ to the target
	### output mechanism. Subclasses can call this with a block which will
	### be passed the formatted message. If no block is supplied by the
	### child, this method will check to see if $DEBUG is set, and if it is,
	### write the log message to $stderr.
	def write( time, level, name, frame, msg )
		escaped_msg = escape_html( msg )
		escaped_name = escape_html( name )
		html = @format.interpolate( binding )

		@io.puts( html )
	end


end # class Arrow::Logger::HtmlOutputter

