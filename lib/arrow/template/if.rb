#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::IfDirective class, a derivative of
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
# == Rcsid
# 
# $Id: if.rb,v 1.7 2004/01/19 03:21:08 deveiant Exp $
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

require 'arrow/template'
require 'arrow/template/nodes'

module Arrow
class Template

	### Conditional directive node object class.
	class IfDirective < Arrow::Template::BracketingDirective
		include Arrow::Template::ConditionalDirective

		require 'arrow/template/else'
		require 'arrow/template/elsif'

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.7 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: if.rb,v 1.7 2004/01/19 03:21:08 deveiant Exp $


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		#########
		protected
		#########

		### Render the contents of the conditional if it evaluates to +true+, or
		### the nodes after 'elsif' or 'else' subnodes if their conditions are
		### met.
		def renderContents( template, scope )
			cond = hasBeenTrue = self.evaluate( template, scope )

			nodes = []
			
			# Now splice out the chunk of nodes that should be rendered based on
			# the conditional.
			@subnodes.each {|node|
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
			}

			return template.render( nodes, scope )
		end



	end # class IfDirective

end # class Template
end # module Arrow


