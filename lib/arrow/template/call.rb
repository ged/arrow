#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::CallDirective class, a derivative of
# Arrow::Template::ContainerDirective. This is the class which defines the
# behaviour of the 'call' template directive.
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

		# CVS version string
		Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

		# CVS Id string
		Rcsid = %q$Id: call.rb,v 1.1 2003/10/13 04:20:13 deveiant Exp $

	end # class CallDirective

end # class Template
end # module Arrow


