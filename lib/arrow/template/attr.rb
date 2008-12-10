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
class Arrow::Template::AttrDirective < Arrow::Template::AttributeDirective # :nodoc:

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$
	

end # class Arrow::Template::AttrDirective

