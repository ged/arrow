#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::ForDirective class, a derivative of
# Arrow::Template::BracketingDirective. This is the class which defines the
# behaviour of the 'for' template directive.
#
# The format of the directive is:
#
#   <?for <arglist> in <obj>?>...<?end for?>
#
# This directive iterates over all the items in an Enumerable object (via the
# #entities method), rendering the contents once for each object. The specified
# #<em>arglist</em> is similar to Ruby's argument lists: it supports defaults,
# as well as array (e.g., <tt>*rest</tt>) and hash arguments.
#
# While the contents are rendering, a special attribute named <em>iterator</em>
# is set to an Arrow::Template::Iterator object, which can be used to get
# information about the iteration itself. This directive doesn't add anything to
# the output directly, but relies on its subnodes for content.
# 
# This directive only works with Enumerable objects; for other objects with
# iterators or blocks, use the <?yield?> directive.
#
# === Examples
#
#  <!-- Iterate over the headers in a request -->
#  <?for name, value in request.headers_in ?>
#    <strong><?attr name?>:</strong> <?attr value?><br/>
#  <?end for?>
#
#  <!-- Same thing, but this time in a table with alternating styles for each
#       row. -->
#  <table>
#  <?for name, value in request.headers_in ?>
#  <?if iterator.even? ?>
#    <tr class="even-row">
#  <?else?>
#    <tr class="odd-row">
#  <?end if?>
#      <td><?attr name?></td> <td><?attr value?></td>
#    </tr>
#  <?end for?>
#  </table>
#
#  <!-- Pair up words with their lengths and sort them shortest first, then
#       print them out with their lengths -->
#  <?for word, length in tests.
#        collect {|item| [item, item.length]}.
#        sort_by {|item| item[1]} ?>
#  	<?attr word?>: <?attr length?>
#  <?end for?>
#
# == Rcsid
# 
# $Id: for.rb,v 1.3 2004/01/19 03:20:51 deveiant Exp $
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
require 'arrow/template'
require 'arrow/template/nodes'
require 'arrow/template/iterator'

module Arrow
class Template

	### The class which defines the behaviour of the 'for'
	### template directive.
	class ForDirective < Arrow::Template::BracketingDirective
		include Arrow::Template::Parser::Patterns

		# CVS version string
		Version = /([\d\.]+)/.match( %q{$Revision: 1.3 $} )[1]

		# CVS Id string
		Rcsid = %q$Id: for.rb,v 1.3 2004/01/19 03:20:51 deveiant Exp $

		# The regexp for matching the 'in' part of the directive
		IN = WHITESPACE + /in/i + WHITESPACE


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new Arrow::Template::ForDirective object.
		def initialize( body, parser, state )
			@args = []
			@pureargs = []
			super
		end


		######
		public
		######

		# The argument list for the iterator, with sigils and defaults, if any.
		attr_reader :args

		# The argument list for the iterator, with any sigils and defaults
		# stripped away.
		attr_reader :pureargs


		#########
		protected
		#########

		### Parse the contents of the directive.
		def parseDirectiveContents( parser, state )
			@args, @pureargs = parser.scanForArgList( state )
			return nil unless @args

			state.scanner.skip( IN ) or
				raise ParseError, "no 'in' for 'for'"

			super
		end


		### Render the directive's bracketed nodes once for each item in the
		### iterated content.
		def renderSubnodes( attribute, template, scope )
			res = []

			iterator = Arrow::Template::Iterator::new( attribute )
			iterator.each {|iter,*blockArgs|
				#self.log.debug "[FOR] Block args are: %p" % [ blockArgs ]
				attributes = {}
				blockArgs.zip( self.pureargs ) {|pair|
					attributes[ pair[1] ] = pair[0]
				}
				attributes['iterator'] = iter

				#self.log.debug "  override attributes are: %p" % [ attributes ]
				template.withOverriddenAttributes( attributes ) {|template|
					res << template.render( @subnodes, scope )
				}
			}

			return *res
		end



	end # class ForDirective

end # class Template
end # module Arrow


