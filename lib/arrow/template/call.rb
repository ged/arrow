#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::CallDirective class, a derivative of
# Arrow::Template::ContainerDirective. This is the class which defines the
# behaviour of the 'call' template directive.
# 
# == Syntax
#
#   <?call 1+1?>
#   <?call foo.to_html?>
#   <?call arbitrary(Ruby.code)?>
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
require 'arrow/template/nodes'

module Arrow
class Template

	### The class which defines the behaviour of the 'call'
	### template directive.
	class CallDirective < Arrow::Template::AttributeDirective

		# SVN Revision
		SVNRev = %q$Rev$
		
		# SVN Id
		SVNId = %q$Id$
		
		# SVN URL
		SVNURL = %q$URL$

	end # class CallDirective

end # class Template
end # module Arrow


