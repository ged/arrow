#!/usr/bin/ruby
# 
# This file contains the base node classes which are used to parse and define
# behaviour for Arrow::Template objects.
#
# The classes defined in this file are:
#
# [<b>Arrow::Template::Node</b>]
#   The abstract base node class.
# 
# [<b>Arrow::Template::TextNode</b>]
#   The basic content node class. Used to contain chunks of the plain
#   (non-directive) content of the template.
# 
# [<b>Arrow::Template::Directive</b>]
#   The abstract superclass for directives. Directives are tags in the template
#   source which define a particular behaviour and possibly rendered content for
#   the template object.
# 
# [<b>Arrow::Template::AttributeDirective</b>]
#   An abstract superclass for nodes which add a content field and
#   accessor/mutator methods to the template object. Deriviatives of this class
#   are like fill-in fields in the template that are populated with content by
#   whatever system uses the template.
# 
# [<b>Arrow::Template::BracketingDirective</b>]
#   An abstract superclass for nodes which contain other nodes as well as
#   defining their own behaviour and content. Derivatives of this class are used
#   to build conditional or iterated parts of a template.
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

require 'strscan'
require 'forwardable'
require 'pluginfactory'

require 'arrow/utils'
require 'arrow/mixins'
require 'arrow/template'

module Arrow
class Template

	### The abstract base node class.
	class Node < Arrow::Object

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Provide initialization for all derivative Arrow::Template::Node
		### objects.
		def initialize( type='generic' ) # :notnew:
			@type = type
			super()
		end


		######
		public
		######

		# The type of the node
		attr_reader :type


		### Returns +true+ for nodes which generate output themselves (as
		### opposed to ones which generate output through subnodes). This is
		### used for eliding blank lines from the node tree.
		def isRenderingNode?
			false
		end
		alias_method :rendering?, :isRenderingNode?
		

		### Install the node object into the given +template+ object.
		def addToTemplate( template )
			template.installNode( self )
		end


		### Return the node as a String.
		def to_s
			""
		end


		### Return the receiver and any subnodes as a flattened Array of nodes.
		def to_a
			[self]
		end


		### Render the node to text.
		def render( template, scope )
			return [ self.to_s ]
		end


		### Return a human-readable version of the Node object suitable for
		### debugging messages.
		def inspect
			"<%s Node>" % @type.capitalize
		end


		### Return an HTML fragment that can be used to represent the node
		### symbolically in a web-based introspection interface.
		def to_html
			content = nil

			if block_given? 
				content = yield
			else
				content = ""
			end

			nodeclass = self.cssClass

			%q{<div class="node %s"><div class="node-head %s-head">%s</div>
				<div class="node-body %s-body">%s</div></div>} % [
				nodeclass, nodeclass,
				self.class.name.sub(/Arrow::Template::/, ''),
				nodeclass,
				content,
			]
		end


		#########
		protected
		#########

		### Return the HTML element class attribute that corresponds to this node.
		def cssClass
			nodeclass = self.class.name.
				sub(/Arrow::Template::/, '').
				gsub( /::/, '-' ).
				gsub( /([a-z])([A-Z])/, "\\1-\\2" ).
				gsub( /[^-\w]+/, '' ).
				downcase
			nodeclass << "-node" unless /-node$/.match( nodeclass )

			return nodeclass
		end


		### Escape special characters in the given +string+ for display in an
		### HTML inspection interface. This escapes common invisible characters
		### like tabs and carriage-returns in additional to the regular HTML
		### escapes.
		def escapeHTML( string )
			return "nil" if string.nil?
			string = string.inspect unless string.is_a?( String )
			string.
				gsub(/&/, '&amp;').
				gsub(/</, '&lt;').
				gsub(/>/, '&gt;').
				gsub(/\n/, '&#8629;').
				gsub(/\t/, '&#8594;')
		end

	end # class Node


	### The plain-content node object class.  Instances of this class are
	### nodes in a syntax tree which represents the textual contents of an
	### Arrow::Template object.
	class TextNode < Arrow::Template::Node

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new Arrow::Template::TextNode object with the given +body+.
		def initialize( body, type="text" )
			@body = body
			super( type )
		end

		######
		public
		######
		
		# The node body
		attr_accessor :body


		### Match operator -- if +obj+ is a Regexp, use it as a pattern to match
		### against the node's body. If +obj+ is a String, look for it in the
		### node's body, similar to String#index. Returns the position the match
		### starts, or nil if there is no match. Otherwise, invokes obj#=~,
		### passing the node's body as an argument.
		def =~( obj )
			case obj
			when Regexp
				obj.match( self.body )
			when String
				self.body.index( obj )
			else
				obj.=~( self.body )
			end
		end


		### Returns +true+ for nodes which generate output themselves (as
		### opposed to ones which generate output through subnodes). This is
		### used for eliding blank lines from the node tree.
		def isRenderingNode?
			true
		end
		

		### Return the node as a String.
		def to_s
			self.body.to_s
		end


		### Return an HTML fragment that can be used to represent the node
		### symbolically in a web-based introspection interface.
		def to_html
			super { self.escapeHTML(@body) }
		end


		### Return a human-readable version of the object suitable for debugging
		### messages.
		def inspect
			%Q{<%s Node: %s>} % [ @type.capitalize, @body.inspect ]
		end
	
	end # class TextNode


	### A comment node object class. Instances of this class are nodes in a
	### syntax tree which represent the invisible markup useful for diagnosis or
	### debugging.
	class CommentNode < Arrow::Template::TextNode

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new Arrow::Template::TextNode object with the given +body+.
		def initialize( body, type='comment' )
			super
		end

		######
		public
		######

		### Render the comment in the context of the specified +template+ and
		### +scope+.
		def render( template, scope )
			[ template.renderComment( self.to_s ) ]
		end


		### Return an HTML fragment that can be used to represent the node
		### symbolically in a web-based introspection interface.
		def to_html
			super { self.escapeHTML(self.to_s) }
		end

	end


	### The abstract directive superclass. Instances of derivatives of this
	### class define template behaviour and content.
	class Directive < Arrow::Template::Node
		include PluginFactory

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Return the list of subdirectories to search for template nodes.
		def self::derivativeDirs
			["arrow/template"]
		end


		### Factory method: overridden from PluginFactory::create to
		### pass the name into constructors for parsing context.
		def self::create( tag, parser, state )
			super( tag, tag, parser, state )
		end


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Initialize a new Directive with the given +type+ (the directive
		### name), +parser+ (Arrow::Template::Parser), and +state+
		### (Arrow::Template::Parser::State object).
		def initialize( type, parser, state )
			super( type )
			self.parseDirectiveContents( parser, state )
		end


		######
		public
		######

		### Render the directive as a String and return it.
		def render( template, scope )
			rary = []
			rary << template.renderComment( self.inspect ) if
				template._config[:debuggingComments]
			
			return rary
		end

		
		### Return a human-readable version of the object suitable for debugging
		### messages.
		def inspect
			%Q{<%s Directive>} % [ @type.capitalize ]
		end


		### Return an HTML fragment that can be used to represent the node
		### symbolically in a web-based introspection interface.
		def to_html

			if block_given?
				callback = Proc::new
				super( &callback )
			else
				fields = instance_variables.sort.collect {|ivar|
					val = instance_variable_get( ivar )
					%q{<span class="ivar"><em>%s:</em> %s</span>} %
						[ ivar, self.escapeHTML(val) ]
				}

				super { fields.join(", ") }
			end
		end


		#########
		protected
		#########

		### Parse the contents of the directive. This is a no-op for this class;
		### it's here to allow delegation of this task to subclasses.
		def parseDirectiveContents( parser, state )
		end


	end # class Directive



	### The attribute directive superclass. Attribute directives are those that
	### present an exterior interface to the controlling system for
	### message-passing and content-injection (e.g., <?attr?>, <?set?>,
	### <?config?>, etc.)
	class AttributeDirective < Arrow::Template::Directive

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Returns +true+ for classes that support a prepended format. (e.g.,
		### <?call "%15s" % foo ?>).
		def self::allowsFormat
			true
		end


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Initialize a new AttributeDirective with the given tag +name+,
		### template +parser+, and parser +state+.
		def initialize( type, parser, state ) # :notnew:
			@name = nil
			@format = nil
			@methodchain = nil
			super
		end


		######
		public
		######

		# The source code for the methodchain that will be used to render the
		# attribute.
		attr_accessor :methodchain

		# The format string that was specified with the directive, if any
		attr_accessor :format

		# The name of the directive, which is used to associate it with a
		# attribute in the template the node belongs to.
		attr_reader :name


		### Returns +true+ for nodes which generate output themselves (as
		### opposed to ones which generate output through subnodes). This is
		### used for eliding blank lines from the node tree.
		def isRenderingNode?
			true
		end
		

		### Render the directive node's contents as a String and return it.
		def render( template, scope )
			#self.log.debug "Rendering %p" % self
			rary = super

			rary.push( *(self.renderContents( template, scope )) )
			return rary
		end


		### Return a human-readable version of the object suitable for debugging
		### messages.
		def inspect
			%Q{<%s %s%s (Format: %p)>} % [
				@type.capitalize,
				@name,
				@methodchain.empty? ? "" : "." + @methodchain,
				@format,
			]
		end


		### Return an HTML fragment that can be used to represent the node
		### symbolically in a web-based introspection interface.
		def to_html
			html = ''
			if @format
				html << %q{"%s" %% } % self.escapeHTML( @format )
			end
			html << %q{<strong>#%s</strong>} % @name
			if @methodchain
				html << self.escapeHTML( @methodchain )
			end

			if block_given?
				html << " " << yield
			end

			super { html }
		end


		#########
		protected
		#########

		### Parse the contents of the directive, looking for an optional format
		### for tags like <?directive "%-15s" % foo ?>, then a required
		### identifier, then an optional methodchain attached to the indetifier.
		def parseDirectiveContents( parser, state )
			super

			# Look for a format
			# :TODO: This check for format allowability should be a bit more
			# graceful, but I can't currently see how it might be done.
			if self.class.allowsFormat
				if fmt = parser.scanForQuotedString( state )
					state.scanner.skip( /\s*%\s*/ ) or
						raise ParseError, "Format missing modulus operator?"
					@format = fmt[1..-2]
					#self.log.debug "Found format %p" % @format
				else
					#self.log.debug "No format string"
					@format = nil
				end
			end

			# Look for the identifier
			@name = parser.scanForIdentifier( state ) or
				raise ParseError, "missing or malformed indentifier"
			#self.log.debug "Set name of %s to %p" %
			#	[ self.class.name, @name ]

			# Now pick up the methodchain if there is one
			@methodchain = parser.scanForMethodChain( state )

			return true
		end


		### Render the contents of the node
		def renderContents( template, scope )
			return self.callMethodChain( template, scope )
		end


		### Build a Proc object that encapsulates the execution necessary to
		### render the directive.
		def buildRenderingProc( template, scope )
			return nil if self.format.nil? && self.methodchain.nil?

			if self.format
				code = %(Proc::new {|%s| "%s" %% %s%s}) % 
					[ self.name, self.format, self.name, self.methodchain ]
			else
				code = "Proc::new {|%s| %s%s}" %
					[ self.name, self.name, self.methodchain ]
			end
			code.untaint

			#self.log.debug "Rendering proc code is: %p" % code
			desc = "[%s (%s): %s]" %
				[ self.class.name, __FILE__, code ]

			return eval( code, scope.getBinding, desc, __LINE__ )
		end


		### Call the node's methodchain, if any, passing the associated
		### attribute as the first argument and any additional +args+ as second
		### and succeeding arguments. Returns the results of the call.
		def callMethodChain( template, scope, *args )
			chain = self.buildRenderingProc( template, scope )
			#self.log.debug "Rendering proc is: %p" % chain

			#self.log.debug "Fetching attribute %p of template %p" %
			#	[ self.name, template ]
			attribute = template.send( self.name )
			#self.log.debug "Attribute to be rendered (%s) is: %p" %
			#	[ self.name, attribute ]

			if chain
				return chain.call( attribute, *args )
			else
				return attribute
			end
		end


	end # class AttributeDirective


	### The base bracketing directive class. Bracketing directives are
	### branching, filtering, and repetition directives in the template's AST
	### (e.g., <?foreach?>, <?if?>).
	class BracketingDirective < AttributeDirective

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Initialize a new BracketingDirective object with the specified
		### +type+, +parser+, and +state+.
		def initialize( type, parser, state ) # :notnew:
			@subnodes = []
			super
		end
		

		######
		public
		######

		# The node's contained subnodes tree
		attr_reader :subnodes


		### Returns +true+ for nodes which generate output themselves (as
		### opposed to ones which generate output through subnodes). This is
		### used for eliding blank lines from the node tree.
		def isRenderingNode?
			false
		end
		

		### Install the behaviour defined by the directive and its subnodes
		### into the given +template+ object. This by default just installs
		### each of its subnodes.
		def addToTemplate( template )
			super
			self.subnodes.each {|node|
				template.installNode( node )
			}
		end


		### Return the receiver and any subnodes as a flattened Array of nodes.
		def to_a
			ary = [self]
			@subnodes.each {|node| ary += node.to_a }

			return ary
		end


		### Return an HTML fragment that can be used to represent the node
		### symbolically in a web-based introspection interface.
		def to_html
			nodeclass = self.cssClass

			super {
				%q{<div class="node-subtree %s-subtree">
					<div class="node-subtree-head %s-subtree-head"
					>Subnodes</div>%s</div>} % [
					nodeclass, nodeclass,
					@subnodes.collect {|node| node.to_html}.join
				]
			}
		end



		#########
		protected
		#########

		### Parse the contents of the directive. If a block is given (ie., by a
		### subclass's implementation), call it immediately after parsing an
		### optional format, mandatory identifier, and optional
		### methodchain. Then look for the end of the current directive tag, and
		### recurse into the parser for any nodes contained between this
		### directive and its <?end?>.
		def parseDirectiveContents( parser, state )
			super

			# Let subclasses implement further inner-tag parsing if they want
			# to.
			if block_given?
				rval = yield( parser, state )
				return nil if !rval
			end

			# Put the pointer after the closing tag 
			parser.scanForTagEnding( state ) or
				raise ParseError, "couldn't find tag end for '#@name'"

			# Parse the content between this directive and the next <?end?>.
			@subnodes.replace( parser.scanForNodes(state, type, self) )

			return true
		end


		### Use the contents of the associated attribute to render the
		### receiver's subnodes in the specified +scope+.
		def renderContents( template, scope )
			res = super
			self.renderSubnodes( res, template, scope )
		end


		### Render each of the directive's bracketed nodes with the given
		### +item+, +template+, and evaluation +scope+.
		def renderSubnodes( item, template, scope )
			template.withOverriddenAttributes( scope, self.name => item ) {|template|
				template.render( @subnodes, scope )
			}
		end

	end # class BracketingDirective


	### Mixin which adds the notion of boolean evaluability to a directive.
	module ConditionalDirective

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		######
		public
		######

		### Returns +true+ for nodes which generate output themselves (as
		### opposed to ones which generate output through subnodes). This is
		### used for eliding blank lines from the node tree.
		def isRenderingNode?
			false
		end
		

		### Returns +true+ if this Directive, in the context of the given
		### +template+ (an Arrow::Template) and +scope+ (a Binding object),
		### should be considered "true".
		def evaluate( template, scope )
			rval = self.callMethodChain( template, scope )

			#self.log.debug "Methodchain evaluated to %s: %p" %
			#	[ rval ? "true" : "false", rval ]
			return rval ? true : false
		end

	end

end # class Template
end # module Arrow


