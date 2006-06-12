#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::ElsifDirective class, a derivative of
# Arrow::Template::Directive. This is the class which defines the behaviour of
# the 'elsif' template directive.
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

### The class which defines the behaviour of the 'elsif' template directive.
class Arrow::Template::ElsifDirective < Arrow::Template::AttributeDirective # :nodoc:
	include Arrow::Template::ConditionalDirective

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
				"elsif outside of conditional directive (%p)" %
				state.current_branch_node
		end
			
		super
	end


end # class Arrow::Template::Elsif

