#!/usr/bin/env ruby

require 'arrow/exceptions'
require 'arrow/path'
require 'arrow/template/call'

require 'pp'

# The Arrow::Template::PrettyPrintDirective class, a
# derivative of Arrow::Template::CallDirective. This is the class which
# defines the behaviour of the 'prettyprint' template directive, which
# prettyprints and HTML-escapes its associated attribute/s.
# 
# == Syntax
#
#   <pre><?prettyprint object ?></pre>
#
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Template::PrettyPrintDirective < Arrow::Template::CallDirective # :nodoc:

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$
	
	
	### Render the content and return it as prettyprinted text.
	def render( template, scope )
		rawary = super
		rary = []

		rawary.each do |item|
			ppstring = ''
			PP.pp( item, ppstring )
			
			rary << ppstring.
				gsub( /&/, '&amp;' ).
				gsub( /</, '&lt;' ).
				gsub( />/, '&gt;' )
		end
		
		return rary
	end

end # class Arrow::Template::PrettyPrint


