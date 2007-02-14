#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::URLEncodeDirective class, a derivative of
# Arrow::Template::CallDirective. This is the class which defines the
# behaviour of the 'urlencode' template directive.
# 
# == Rcsid
# 
# $Id$
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

require 'arrow/exceptions'
require 'arrow/utils'
require 'arrow/template/nodes'
require 'arrow/template/call'

### The class which defines the behaviour of the 'urlencode'
### template directive.
class Arrow::Template::URLEncodeDirective < Arrow::Template::CallDirective # :nodoc:

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Non-URIC Characters (RFC 2396)
	NonUricRegexp = /[^A-Za-z0-9\-_.!~*'()]/


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
			rary << line.to_s.gsub( NonUricRegexp ) do |match|
				"%%%02x" % [ match[0] ]
			end
		end

		return rary
	end

end # class Arrow::Template::URLEncodeDirective
