#!/usr/bin/env ruby
# 
# This file contains the Arrow::Template::SetDirective class, a derivative of
# Arrow::Template::Directive. This is the class which defines the behaviour of
# the 'set' template directive.
# 
# == Syntax
#
#   <?set foo 1?>
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

require 'arrow/template/nodes'

### The class which defines the behaviour of the 'set' template directive.
class Arrow::Template::SetDirective < Arrow::Template::Directive # :nodoc:

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$
	

	### Create and return a new Arrow::Template::SetDirective object.
	def initialize( type, parser, state )
		@name = nil
		@value = nil

		super
	end


	######
	public
	######

	# The name of the definition set by this directive.
	attr_reader :name

	# The raw (unevaluated) value of the definition
	attr_reader :value


	### Render the directive. This adds the defined variable to the
	### +template+'s rendering +scope+ and returns an empty string (or a
	### comment if +:debuggingComments+ is turned on in the template.
	def render( template, scope )
		rval = super

		self.log.debug "Evaling <%s> for 'set' directive." % @value
		template[@name] = eval( @value, scope.get_binding, __FILE__, __LINE__ )

		if template._config[:debuggingComments]
			rval << template.render_comment( "Set '%s' to '%s'" %
				[ @name, template[@name] ] )
		end

		return rval
	end


	#########
	protected
	#########

	### Parse the contents of the directive.
	def parse_directive_contents( parser, state )
		@name = parser.scan_for_identifier( state )

		state.scanner.skip( /\s*=\s*/ )

		@value = parser.scan_for_identifier( state ) ||
			parser.scan_for_quoted_string( state ) or
			raise Arrow::ParseError, "No value for 'set' directive"

		if (( chain = parser.scan_for_methodchain(state) ))
			@value << chain
		end
	end

end # class Arrow::Template::SetDirective


