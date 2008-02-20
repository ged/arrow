#!/usr/bin/env ruby
# 
# Output logging messages in HTML fragments with classes that match 
# their level. 
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
require 'arrow/logger/fileoutputter'

### Output logging messages in ANSI colors according to their level
class Arrow::Logger::HtmlOutputter < Arrow::Logger::FileOutputter
	include Arrow::HTMLUtilities

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Default decription used when creating instances
	DEFAULT_DESCRIPTION = "HTML Fragment Logging Outputter"

	# The default logging output format
	HTML_FORMAT = %q{
	<div class="log-message #{level}">
		<span class="log-time">#{time.strftime('%Y/%m/%d %H:%M:%S')}</span>
		<span class="log-level">#{level}</span>
		:
		<span class="log-name">#{name}</span>
		<span class="log-frame">#{frame ? '('+frame+'): ' : ''}</span>
		<span class="log-message-text">#{escaped_msg}</span>
	</div>
	}


	### Override the default to add color scheme instance variable
	def initialize( uri, description=DEFAULT_DESCRIPTION, format='' ) # :notnew:
		super
	end


	### Write the given +level+, +name+, +frame+, and +msg+ to the target
	### output mechanism. Subclasses can call this with a block which will
	### be passed the formatted message. If no block is supplied by the
	### child, this method will check to see if $DEBUG is set, and if it is,
	### write the log message to $deferr.
	def write( time, level, name, frame, msg )
		escaped_msg = escape_html( msg )
		html = @format.interpolate( binding )

		if block_given?
			yield( html )
		else
			$deferr.puts( html ) if $DEBUG
		end
	end


end # class Arrow::Logger::HtmlOutputter
