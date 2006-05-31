#!/usr/bin/ruby
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
#  $Id: prettyprint.rb 183 2004-08-23 06:10:32Z ged $
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

require 'pp'

### The class which defines the behaviour of the 'prettyprint'
### template directive.
class Arrow::Template::PrettyPrintDirective < Arrow::Template::CallDirective

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id: prettyprint.rb 183 2004-08-23 06:10:32Z ged $
	
	
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


