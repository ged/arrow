#!/usr/bin/ruby
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
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'arrow/exceptions'
require 'arrow/utils'
require 'arrow/template/nodes'

module Arrow
class Template

	### The class which defines the behaviour of the 'else'
	### template directive.
	class ElseDirective < Arrow::Template::Directive

		# SVN Revision
		SVNRev = %q$Rev$
		
		# SVN Id
		SVNId = %q$Id$
		
		# SVN URL
		SVNURL = %q$URL$

		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new Arrow::Template::ElsifDirective object.
		def initialize( body, parser, state )
			unless state.currentBranchNode.is_a?( ConditionalDirective )
				raise Arrow::TemplateError,
					"else outside of conditional directive (%p)" %
					state.currentBranchNode
			end
				
			super
		end

	end # class ElseDirective

end # class Template
end # module Arrow


