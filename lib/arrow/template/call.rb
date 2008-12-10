#!/usr/bin/env ruby

require 'arrow/exceptions'
require 'arrow/path'
require 'arrow/template/nodes'

# The Arrow::Template::CallDirective class, a derivative of
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
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#
class Arrow::Template::CallDirective < Arrow::Template::AttributeDirective # :nodoc:

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$

end # class Arrow::Template::CallDirective
