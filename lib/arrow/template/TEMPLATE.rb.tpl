#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::(>>>class<<<) class, a derivative of
# Arrow::Template::(>>>superclass<<<). This is the class which defines the
# behaviour of the '(>>>directive<<<)' template directive.
# 
# == Rcsid
# 
# $Id: TEMPLATE.rb.tpl,v 1.1 2003/08/13 12:42:57 deveiant Exp $
# 
# == Authors
# 
# * (>>>USER_NAME<<<) <(>>>AUTHOR<<<)>
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

	### The class which defines the behaviour of the '(>>>directive<<<)'
	### template directive.
	class (>>>class<<<) < Arrow::Template::(>>>superclass<<<)

		# CVS version string
		Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

		# CVS Id string
		Rcsid = %q$Id: TEMPLATE.rb.tpl,v 1.1 2003/08/13 12:42:57 deveiant Exp $

	end # class (>>>class<<<)

end # class Template
end # module Arrow


>>>TEMPLATE-DEFINITION-SECTION<<<
("class" "Class: Arrow::Template::")
("superclass" "Derives from: Arrow::Template::")
("directive" "Which directive does this class implement: ")


