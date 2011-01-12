#!/usr/bin/env ruby

require 'arrow/exceptions'
require 'arrow/path'
require 'arrow/template/nodes'

# The Arrow::Arrow::Template::AttrDirective class, a derivative of Arrow::Directive. 
# This is the class which defines the behaviour of the 'attr' template directive.
# 
# == Syntax
#
#   <?attr foo ?>
#   <?attr "%0.2f" % foo ?>
#
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Template::AttrDirective < Arrow::Template::AttributeDirective # :nodoc:

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$
	

end # class Arrow::Template::AttrDirective

