#!/usr/bin/env ruby
# 
# This file contains the Arrow::Template::UnlessDirective class, a derivative of
# Arrow::Template::BracketingDirective. Instances of this class represent a
# section of a template that is rendered conditionally.
#
# The formats the directive supports are:
#
#   <?unless <name>?>...<?end unless?>
#   <?unless <name>.<methodchain>?>...<?end unless?>
#   <?unless <name> (matches|=~) <regex>?>...<?end unless?>
#   <?unless <name>.<methodchain> (matches|=~) <regex>?>...<?end unless?>
# 
# Note that this directive does not support all possible Ruby expressions in the
# conditional, and must have a valid associated identifier (the <em>name</em>
# bit).
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

require 'arrow/template'
require 'arrow/template/nodes'

### Conditional directive node object class.
class Arrow::Template::UnlessDirective < Arrow::Template::BracketingDirective # :nodoc:
	include Arrow::Template::ConditionalDirective

	require 'arrow/template/else'
	require 'arrow/template/elsif'

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	#########
	protected
	#########

	### Render the contents of the conditional if it evaluates to +false+, or
	### the nodes after 'elsif' or 'else' subnodes if their conditions are
	### met.
	def render_contents( template, scope )
		cond = has_been_true = !self.evaluate( template, scope )

		nodes = []
		
		# Now splice out the chunk of nodes that should be rendered based on
		# the conditional.
		@subnodes.each do |node|
			case node
			when Arrow::Template::ElsifDirective
				if !has_been_true
					cond = has_been_true = node.evaluate( template, scope )
				else
					cond = false
				end

			when Arrow::Template::ElseDirective
				if !has_been_true
					cond = has_been_true = true
				else
					cond = false
				end

			else
				nodes.push( node ) if cond
			end
		end

		return template.render( nodes, scope )
	end



end # class Arrow::Template::UnlessDirective
