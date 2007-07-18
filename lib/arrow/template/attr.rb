#!/usr/bin/env ruby
# 
# This file contains the Arrow::Arrow::Template::AttrDirective class, a
# derivative of Arrow::Directive. This is the class which defines the behaviour
# of the 'attr' template directive.
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
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'arrow/exceptions'
require 'arrow/utils'
require 'arrow/template/nodes'

### The class which defines the behaviour of the 'attr' template directive. This
### is just the AttributeDirective plus some behaviours for interaction with the
### template.
class Arrow::Template::AttrDirective < Arrow::Template::AttributeDirective # :nodoc:

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$
	

end # class Arrow::Template::AttrDirective

