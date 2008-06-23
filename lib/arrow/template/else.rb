#!/usr/bin/env ruby
# 
# This file contains the Arrow::Template::ElseDirective class, a derivative of
# Arrow::Template::Directive. This is the class which defines the behaviour of
# the 'else' template directive.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
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

### The class which defines the behaviour of the 'else'
### template directive.
class Arrow::Template::ElseDirective < Arrow::Template::Directive # :nodoc:

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$
	

	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Template::ElsifDirective object.
	def initialize( body, parser, state )
		unless state.current_branch_node.is_a?( Arrow::Template::ConditionalDirective )
			raise Arrow::TemplateError,
				"else outside of conditional directive (%p)" %
				state.current_branch_node
		end
			
		super
	end

end # class Arrow::Template::ElseDirective
