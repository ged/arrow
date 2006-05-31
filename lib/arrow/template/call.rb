#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::CallDirective class, a derivative of
# Arrow::Template::AttributeDirective. This is the class which defines the
# behaviour of the 'call' template directive.
# 
# == Syntax
#
#   <?call foo.to_html ?>
#   <?call var.any(other_var.method).chain ?>
#   <?call "$%0.2f" % var.any(other_var.method).chain ?>
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

### The class which defines the behaviour of the 'call'
### template directive.
class Arrow::Template::CallDirective < Arrow::Template::AttributeDirective

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$

end # class Arrow::Template::CallDirective
