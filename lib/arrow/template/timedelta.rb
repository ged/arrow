#!/usr/bin/env ruby

require 'arrow/exceptions'
require 'arrow/path'
require 'arrow/template/nodes'
require 'arrow/template/call'

# The Arrow::Template::TimeDeltaDirective class, a derivative of
# Arrow::Template::CallDirective. This plugin defines the 'timedelta' template directive.
# 
# === Syntax
#
#   <?timedelta process.uptime ?>
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
#--
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#
class Arrow::Template::TimeDeltaDirective < Arrow::Template::CallDirective # :nodoc:

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Approximate Time Constants (in seconds)
	MINUTES = 60
	HOURS   = 60  * MINUTES
	DAYS    = 24  * HOURS
	WEEKS   = 7   * DAYS
	MONTHS  = 30  * DAYS
	YEARS   = 365.25 * DAYS

	######
	public
	######

	### Render the content and return it as URL-escaped text.
	def render( template, scope )
		rawary = super
		rary = []

		# Try our best to skip debugging comments
		if template._config[:debuggingComments]
			rary.push( rawary.shift ) if /^<!--.*-->$/ =~ rawary.first
		end

		rawary.each do |line|
			rary << time_delta_string( line.to_i )
		end

		return rary
	end


	#######
	private
	#######

	### Return a string describing the amount of time in the given number of
	### seconds in terms a human can understand easily.
	def time_delta_string( seconds )
		return 'less than a minute' if seconds < 60

		if seconds < 50 * 60
			return "%d minute%s" % [seconds / 60, seconds/60 == 1 ? '' : 's']
		end

		return 'about an hour'					if seconds < 90 * MINUTES
		return "%d hours" % [seconds / HOURS]	if seconds < 18 * HOURS
		return 'one day' 						if seconds <  1 * DAYS
		return 'about a day' 					if seconds <  2 * DAYS
		return "%d days" % [seconds / DAYS] 	if seconds <  1 * WEEKS
		return 'about a week' 					if seconds <  2 * WEEKS
		return "%d weeks" % [seconds / WEEKS] 	if seconds <  3 * MONTHS
		return "%d months" % [seconds / MONTHS] if seconds <  2 * YEARS
		return "%d years" % [seconds / YEARS]
	end

end # class Arrow::Template::URLEncodeDirective
