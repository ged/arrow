#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::YieldDirective class, a derivative
# of Arrow::Template::BracketingDirective. This is the class which defines the
# behaviour of the 'yield' template directive.
# 
# The formats the directives can take are:
#
#  <?yield <args> from <attribute>.<block_method> ?>
#
# The <em>args</em> portion is similar to Ruby argument lists: it supports
# defaults, <tt>*vars</tt>, and hash arguments.
#
# == Examples
#
#  <!-- Iterate over the incoming headers of an Apache::Request -->
#  <?yield name, value from request.headers_in.each ?>
#    <?attr name ?>: <?escape value ?>
#  <?end yield?>
#
#  
# == Rcsid
# 
# $Id: yield.rb,v 1.4 2004/01/19 03:30:30 deveiant Exp $
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

	### The class which defines the behaviour of the 'yield'
	### template directive.
	class YieldDirective < Arrow::Template::BracketingDirective
		include Arrow::Template::Parser::Patterns

		# CVS version string
		Version = /([\d\.]+)/.match( %q{$Revision: 1.4 $} )[1]

		# CVS Id string
		Rcsid = %q$Id: yield.rb,v 1.4 2004/01/19 03:30:30 deveiant Exp $

		# The regexp format of the 'yield' part of the directive tag.
		FROM = WHITESPACE + /from/i + WHITESPACE


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Returns +false+; disallows prepended formats.
		def self::allowsFormat
			false
		end
		

		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Initialize a new YieldDirective object with the specified +type+,
		### +parser+, and +state+.
		def initialize( type, parser, state )
			@args = []
			@pureargs = []
			super
		end


		######
		public
		######

		# The argument list for the yield block, with sigils and defaults, if any.
		attr_reader :args

		# The argument list for the callback, with any sigils and defaults
		# stripped away.
		attr_reader :pureargs


		#########
		protected
		#########

		### Parse the contents of the directive, looking for an optional format
		### for tags like <?directive "%-15s" % foo ?>, then a required
		### identifier, then an optional methodchain attached to the indetifier.
		def parseDirectiveContents( parser, state )
			@args, @pureargs = parser.scanForArgList( state )
			return nil unless @args
			state.scanner.skip( FROM ) or
				raise ParseError, "no 'from' for yield"

			super
		end


		### Build a Proc object that encapsulates the execution necessary to
		### render the directive.
		def buildRenderingProc( template, scope )
			code = %q{
				Proc::new {|__item, __callback|
					res = []
					__item%s {|%s| res << __callback.call(%s)}
					res
				}
			} % [ self.methodchain, self.args.join(","), self.pureargs.join(",") ]
			code.untaint

			#self.log.debug "Rendering proc code is: %p" % code
			desc = "[%s (%s): %s]" %
				[ self.class.name, __FILE__, self.methodchain ]

			return eval( code, scope.getBinding, desc, __LINE__ )
		end


		### Pass a callback to our inner node-rendering method as the block for
		### the specified. Builds a callback which is yielded to from within the
		### block passed to whatever this directive is calling, which in turn
		### renders each of its subnodes with the arguments specified by the
		### yield.
		def renderContents( template, scope )
			#self.log.debug "Bulding callback for rendering subnodes..."
			callback = Proc::new {|*blockArgs|
				res = []
				attributes = {}
				blockArgs.zip( self.pureargs ) {|pair|
					attributes[ pair[1] ] = pair[0]
				}
				#self.log.debug "  override attributes are: %p" % [ attributes ]
				template.withOverriddenAttributes( attributes ) {|template|
					res << template.render( @subnodes, scope )
				}

				res
			}

			#self.log.debug "calling method chain; callback: %p" % callback
			self.callMethodChain( template, scope, callback )
		end


	end # class YieldDirective

end # class Template
end # module Arrow


