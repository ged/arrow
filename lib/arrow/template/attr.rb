#!/usr/bin/ruby
# 
# This file contains the Arrow::Arrow::Template::AttrDirective class, a
# derivative of Arrow::Directive. This is the class which defines the behaviour
# of the 'attr' template directive.
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

	### The class which defines the behaviour of the 'attr' template
	### directive. This is just the AttributeDirective plus some behaviours for
	### interaction with the template.
	class AttrDirective < Arrow::Template::AttributeDirective

		# SVN Revision
		SVNRev = %q$Rev$
		
		# SVN Id
		SVNId = %q$Id$
		
		# SVN URL
		SVNURL = %q$URL$

	end # class AttrDirective

end # class Template
end # module Arrow

