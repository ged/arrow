#!/usr/bin/env ruby

require 'arrow/exceptions'
require 'arrow/path'
require 'arrow/template/call'

# The Arrow::Template::EscapeDirective class, a derivative of
# Arrow::Template::CallDirective. This is the class which defines the behaviour
# of the 'escape' template directive., which HTML escapes the stringified
# version of its associated attribute/s.
# 
# == Syntax
#
#   <pre><?escape data.to_yaml?></pre>
#   <?escape some_string_with_htmlish_bits?>
#
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Template::EscapeDirective < Arrow::Template::CallDirective # :nodoc:

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$
	
	
	### Render the content and return it as HTML-escaped text.
	def render( template, scope )
		rawary = super
		rary = []

		# Try our best to skip debugging comments
		if template._config[:debuggingComments]
			rary.push( rawary.shift ) if /^<!--.*-->$/ =~ rawary.first
		end

		rawary.each do |line|
			rary << line.to_s.
				gsub( /&/, '&amp;' ).
				gsub( /</, '&lt;' ).
				gsub( />/, '&gt;' ).
				gsub( /"/, '&quot;' )
		end

		return rary
	end

end # class Arrow::Template::Escape
