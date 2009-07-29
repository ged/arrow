#!/usr/bin/env ruby

require 'arrow/mixins'
require 'arrow/logger/outputter'
require 'arrow/logger/htmloutputter'

# Accumulate logging messages in HTML fragments into an Array which can later be fetched.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#
class Arrow::Logger::ArrayOutputter < Arrow::Logger::Outputter
	include Arrow::HTMLUtilities

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Default decription used when creating instances
	DEFAULT_DESCRIPTION = "Array Outputter"

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

	### Override the default to intitialize the Array.
	def initialize( uri, description=DEFAULT_DESCRIPTION, format=HTML_FORMAT ) # :notnew:
		@array = []
		super
	end


	######
	public
	######

	# The Array any output log messages get appended to
	attr_reader :array


	### Write the given +level+, +name+, +frame+, and +msg+ to the target
	### output mechanism. Subclasses can call this with a block which will
	### be passed the formatted message. If no block is supplied by the
	### child, this method will check to see if $DEBUG is set, and if it is,
	### write the log message to $deferr.
	def write( time, level, name, frame, msg )
		escaped_msg = escape_html( msg )
		escaped_name = escape_html( name )
		html = self.format.interpolate( binding )

		@array << html
	end


end # class Arrow::Logger::ArrayOutputter

