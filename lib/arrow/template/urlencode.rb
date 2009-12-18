#!/usr/bin/env ruby

require 'arrow/exceptions'
require 'arrow/path'
require 'arrow/template/nodes'
require 'arrow/template/call'

# The Arrow::Template::URLEncodeDirective class, a derivative of
# Arrow::Template::CallDirective. This is the class which defines the
# behaviour of the 'urlencode' template directive.
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
class Arrow::Template::URLEncodeDirective < Arrow::Template::CallDirective # :nodoc:

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
