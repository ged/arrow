#!/usr/bin/env ruby
# 
# This file contains the Arrow::Template::PrettyPrintDirective class, a
# derivative of Arrow::Template::CallDirective. This is the class which
# defines the behaviour of the 'prettyprint' template directive, which
# prettyprints and HTML-escapes its associated attribute/s.
# 
# == Syntax
#
#   <pre><?prettyprint object ?></pre>
#
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the BASE directory for licensing details.
#

require 'arrow/exceptions'
require 'arrow/utils'
require 'arrow/template/call'

require 'pp'

### The class which defines the behaviour of the 'prettyprint'
### template directive.
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


