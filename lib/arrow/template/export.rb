#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::ExportDirective class, a derivative of
# Arrow::Template::BracketingDirective. This is the class which defines the
# behaviour of the 'export' template directive.
#
# == Syntax
#
#	<?export foo ?>
#	  <!-- Some content for 'foo' attributes of enclosing templates. -->
#	<?end?>
#
# == Subversion Id
# 
# $Id$
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

### The class which defines the behaviour of the '(>>>directive<<<)'
### template directive.
class Arrow::Template::ExportDirective < Arrow::Template::BracketingDirective # :nodoc:
	include Arrow::Template::Parser::Patterns

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$
	


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################
	
	### Disallow formats and methodchains
	def self.allows_format?; false; end
	def self.allows_method_chains?; false; end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################
	
	### Add the imported attributes when this node is rendered.
	def before_rendering( template )
		st = template
		
		while st = st._enclosing_template
			surrogate = template.class.new( self.subnodes )
		
			# :TODO: Does appending to the attribute make more sense?
			st._attributes[ self.name ] = surrogate
		end
	end


	### Add attributes contained by subnodes, but not the attribute
	### for this node itself, which will be looked for in the 
	### enclosing template.
	def add_to_template( template ) # :nodoc:
		self.subnodes.each do |node|
			template.install_node( node )
		end
	end


	#########
	protected
	#########

	### Override the default behavior, which is to render subnodes. Since the
	### whole point of this directive is to give content to a containing 
	### template, this becomes a no-op.
	def render_contents( template, scope )
		return []
	end
	
	
end # class Arrow::Template::ExportDirective
