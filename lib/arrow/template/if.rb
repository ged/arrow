#!/usr/bin/env ruby

require 'arrow/template'
require 'arrow/template/nodes'

# The Arrow::Template::IfDirective class, a derivative of
# Arrow::Template::BracketingDirective. Instances of this class represent a
# section of a template that is rendered conditionally.
#
# The formats the directive supports are:
#
#   <?if <name>?>...<?end if?>
#   <?if <name>.<methodchain>?>...<?end if?>
#   <?if <name> (matches|=~) <regex>?>...<?end if?>
#   <?if <name>.<methodchain> (matches|=~) <regex>?>...<?end if?>
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
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#
class Arrow::Template::IfDirective < Arrow::Template::BracketingDirective # :nodoc:
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

	### Render the contents of the conditional if it evaluates to +true+, or
	### the nodes after 'elsif' or 'else' subnodes if their conditions are
	### met.
	def render_contents( template, scope )
		cond = hasBeenTrue = self.evaluate( template, scope )

		nodes = []
		
		# Now splice out the chunk of nodes that should be rendered based on
		# the conditional.
		@subnodes.each do |node|
			case node
			when Arrow::Template::ElsifDirective
				if !hasBeenTrue
					cond = hasBeenTrue = node.evaluate( template, scope )
				else
					cond = false
				end

			when Arrow::Template::ElseDirective
				if !hasBeenTrue
					cond = hasBeenTrue = true
				else
					cond = false
				end

			else
				nodes.push( node ) if cond
			end
		end

		return template.render( nodes, scope )
	end



end # class Arrow::Template::IfDirective
