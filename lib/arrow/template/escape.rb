#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::Escape class, a derivative of
# Arrow::Template::CallDirective. This is the class which defines the behaviour
# of the 'escape' template directive., which HTML escapes the stringified
# version of its associated attribute/s.
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

require 'arrow/exceptions'
require 'arrow/utils'
require 'arrow/template/call'

module Arrow
class Template

	### The class which defines the behaviour of the 'escape'
	### template directive.
	class EscapeDirective < Arrow::Template::CallDirective

		# SVN Revision
		SVNRev = %q$Rev$
		
		# SVN Id
		SVNId = %q$Id$
		
		# SVN URL
		SVNURL = %q$URL$

		
		### Render the content and return it as HTML-escaped text.
		def render( template, scope )
			rawary = super
			rary = []

			# Try our best to skip debugging comments
			if template._config[:debuggingComments]
				rary.push( rawary.shift ) if /^<!--.*-->$/ =~ rawary.first
			end

			rawary.each {|line|
				rary << line.
					gsub( /&/, '&amp;' ).
					gsub( /</, '&lt;' ).
					gsub( />/, '&gt;' )
			}

			return rary
		end

	end # class Escape

end # class Template
end # module Arrow

