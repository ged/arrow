#!/usr/bin/ruby
# 
# This file contains the Arrow::Arrow::Template::AttrDirective class, a
# derivative of Arrow::Directive. This is the class which defines the behaviour
# of the 'attr' template directive.
# 
# == Rcsid
# 
# $Id: attr.rb,v 1.2 2003/10/13 04:34:23 deveiant Exp $
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

		# CVS version string
		Version = /([\d\.]+)/.match( %q{$Revision: 1.2 $} )[1]

		# CVS Id string
		Rcsid = %q$Id: attr.rb,v 1.2 2003/10/13 04:34:23 deveiant Exp $

	end # class AttrDirective

end # class Template
end # module Arrow

