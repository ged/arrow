#!/usr/bin/env ruby
# 
# This file contains the Arrow::Template::SelectListDirective class, a derivative of
# Arrow::Template::AttributeDirective. This is the class which defines the
# behaviour of the 'selectlist' template directive.
#
# == Syntax
#
#   <?selectlist categories ?><?end?>
#   <?selectlist category FROM categories ?><?end?>
#   <?selectlist category FROM categories.sort_by {|c| c.name } ?><?end?>
#
# == Subversion Id
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <mgranger@rubycrafters.com>
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

### The class which defines the behaviour of the 'selectlist'
### template directive.
class Arrow::Template::SelectListDirective < Arrow::Template::BracketingDirective
	include Arrow::Template::Parser::Patterns

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$

	NAMEDLIST = CAPTURE[ IDENTIFIER ] + /\s+from\s+/i


	### This directive doesn't allow formatting.
	def self::allows_format?
		false
	end
	
	
	### Create a new Arrow::Template::SelectListDirective object.
	def initialize( body, parser, state )
		@select_name = nil
		super
	end


	######
	public
	######

	attr_reader :select_name
	
	

	#########
	protected
	#########

	### Parse the contents of the directive
	def parse_directive_contents( parser, state )
		state.scanner.skip( WHITESPACE )
		
		if state.scanner.scan( NAMEDLIST )
			@select_name = state.scanner[1]
		end

		super

		return true
	end
	

	### Render the directive's bracketed nodes once for each item in the
	### iterated content.
	def render_subnodes( attribute, template, scope )
		res = []

		res << %{<select name="%s">\n} % [ self.select_name || self.name ]
		attribute.each do |attrib|
			res << %{  <option value="%s">%s</option>\n} % [ attrib, attrib ]
		end
		res << %{</select>\n}

		return *res
	end
	

end # class Arrow::Template::SelectListDirective

