#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::YieldDirective class, a derivative
# of Arrow::Template::BracketingDirective. This is the class which defines the
# behaviour of the 'yield' template directive.
# 
# == Syntax
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

### The class which defines the behaviour of the 'yield'
### template directive.
class Arrow::Template::YieldDirective < Arrow::Template::BracketingDirective # :nodoc:
	include Arrow::Template::Parser::Patterns

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The regexp format of the 'yield' part of the directive tag.
	FROM = WHITESPACE + /from/i + WHITESPACE


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Returns +false+; disallows prepended formats.
	def self.allows_format?
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
	def parse_directive_contents( parser, state )
		@args, @pureargs = parser.scan_for_arglist( state )
		return nil unless @args
		state.scanner.skip( FROM ) or
			raise Arrow::ParseError, "no 'from' for yield"

		super
	end


	### Build a Proc object that encapsulates the execution necessary to
	### render the directive.
	def build_rendering_proc( template, scope )
		code = %q{
			Proc.new {|__item, __callback|
				res = []
				__item%s {|%s| res << __callback.call(%s)}
				res
			}
		} % [ self.methodchain, self.args.join(","), self.pureargs.join(",") ]
		code.untaint

		#self.log.debug "Rendering proc code is: %p" % code
		desc = "[%s (%s): %s]" %
			[ self.class.name, __FILE__, self.methodchain ]

		return eval( code, scope.get_binding, desc, __LINE__ )
	end


	### Pass a callback to our inner node-rendering method as the block for
	### the specified. Builds a callback which is yielded to from within the
	### block passed to whatever this directive is calling, which in turn
	### renders each of its subnodes with the arguments specified by the
	### yield.
	def render_contents( template, scope )
		#self.log.debug "Bulding callback for rendering subnodes..."
		callback = Proc.new {|*blockArgs|
			res = []
			attributes = {}
			blockArgs.zip( self.pureargs ) do |pair|
				attributes[ pair[1] ] = pair[0]
			end
			#self.log.debug "  override attributes are: %p" % [ attributes ]
			template.with_overridden_attributes( scope, attributes ) do |template|
				res << template.render( @subnodes, scope )
			end

			res
		}

		#self.log.debug "calling method chain; callback: %p" % callback
		self.call_methodchain( template, scope, callback )
	end


end # class Arrow::Template::YieldDirective


