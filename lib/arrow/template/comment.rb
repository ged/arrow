#!/usr/bin/env ruby

require 'arrow/exceptions'
require 'arrow/path'
require 'arrow/template/nodes'

# The Arrow::Template::Comment class, a derivative of
# Arrow::Template::AttributeDirective. This is the class which defines
# the behaviour of the 'comment' template directive.
#
# == VCS Id
#
# $Id$
#
# == Authors
#
# * Mahlon E. Smith <mahlon@martini.nu>
#
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Template::CommentDirective < Arrow::Template::AttributeDirective # :nodoc:

	######
	public
	######

	### Return an empty string instead of rendering anything within
	### a comment directive.
	def render( template, scope )
		return ''
	end

end # class Arrow::Template::CommentDirective
