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

require 'arrow/logger/fileoutputter'

### Output logging messages in ANSI colors according to their level
class Arrow::Logger::HtmlOutputter < Arrow::Logger::FileOutputter

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Default decription used when creating instances
	DEFAULT_DESCRIPTION = "HTML Fragment Logging Outputter"

	# The default logging output format
	DEFAULT_FORMAT = %q{
	<div class="log-message #{level}">
		<span class="log-time">#{time.strftime('%Y/%m/%d %H:%M:%S')}</span>
		<span class="log-level">#{level}</span>
		:
		<span class="log-name">#{name}</span>
		<span class="log-frame">#{frame ? '('+frame+'): ' : ''}</span>
		<span class="log-message-text">#{msg}</span>
	</div>
	}


	### Override the default to add color scheme instance variable
	def initialize( uri, description=DEFAULT_DESCRIPTION, format=DEFAULT_FORMAT ) # :notnew:
		super
	end


end # class Arrow::Logger::HtmlOutputter

