#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::URLEncodeDirective class, a derivative of
# Arrow::Template::CallDirective. This is the class which defines the
# behaviour of the 'urlencode' template directive.
# 
# == Rcsid
# 
# $Id: TEMPLATE.rb.tpl,v 1.1 2003/08/13 12:42:57 deveiant Exp $
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

module Arrow
class Template

	### The class which defines the behaviour of the 'urlencode'
	### template directive.
	class URLEncodeDirective < Arrow::Template::CallDirective

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

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

			rawary.each {|line|
				rary << line.to_s.gsub( NonUricRegexp ) do |match|
					"%%%x" % match[0]
				end
			}

			return rary
		end

	end # class URLEncodeDirective

end # class Template
end # module Arrow

