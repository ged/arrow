#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::SetDirective class, a derivative of
# Arrow::Template::Directive. This is the class which defines the behaviour of
# the 'set' template directive.
# 
# == Rcsid
# 
# $Id: set.rb,v 1.6 2004/01/19 03:29:58 deveiant Exp $
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

module Arrow
class Template

	### The class which defines the behaviour of the 'set' template directive.
	class SetDirective < Arrow::Template::Directive

		# CVS version string
		Version = /([\d\.]+)/.match( %q{$Revision: 1.6 $} )[1]

		# CVS Id string
		Rcsid = %q$Id: set.rb,v 1.6 2004/01/19 03:29:58 deveiant Exp $

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
			template[@name] = eval( @value, scope.getBinding, __FILE__, __LINE__ )

			if template._config[:debuggingComments]
				rval << template.renderComment( "Set '%s' to '%s'" %
					[ @name, template[@name] ] )
			end

			return rval
		end


		#########
		protected
		#########

		### Parse the contents of the directive.
		def parseDirectiveContents( parser, state )
			@name = parser.scanForIdentifier( state )

			state.scanner.skip( /\s*=\s*/ )

			@value = parser.scanForIdentifier( state ) ||
				parser.scanForQuotedString( state ) or
				raise ParseError, "No value for 'set' directive"

			if (( chain = parser.scanForMethodChain(state) ))
				@value << chain
			end
		end

	end # class SetDirective

end # class Template
end # module Arrow


