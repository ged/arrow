#!/usr/bin/env ruby
# 
# This file contains the Arrow::Template::#{vars[:class]} class, a derivative of
# Arrow::Template::#{vars[:superclass]}. This is the class which defines the
# behaviour of the '#{vars[:directive]}' template directive.
#
# == Syntax
#
#	
#
# == Subversion Id
# 
# $Id: TEMPLATE.rb.tpl,v 1.1 2003/08/13 12:42:57 deveiant Exp $
# 
# == Authors
# 
# * #{user.gecos} <#{vars[:user_email]}>
# 
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the BASE directory for licensing details.
#

require 'arrow/exceptions'
require 'arrow/utils'
require 'arrow/template/nodes'

### The class which defines the behaviour of the '#{vars[:directive]}'
### template directive.
class Arrow::Template::#{vars[:class]} < Arrow::Template::#{vars[:superclass]}

	# SVN Revision
	SVNRev = %q$Rev: 183 $
	
	# SVN Id
	SVNId = %q$Id: import.rb 183 2004-08-23 06:10:32Z ged $
	

	

end # class Arrow::Template::#{vars[:class]}

