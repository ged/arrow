#!/usr/bin/env ruby

require 'pluginfactory'

require 'arrow/path'
require 'arrow/mixins'
require 'arrow/template'

class Arrow::Template

	### The abstract base node class.
	class Node < Arrow::Object
		include Arrow::HTMLUtilities


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
		def is_rendering_node?
			false
		end
		alias_method :rendering?, :is_rendering_node?


		### Install the node object into the given +template+ object.
		def add_to_template( template )
			template.install_node( self )
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

			nodeclass = self.css_class

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
		def css_class
			nodeclass = self.class.name.
				sub(/Arrow::Template::/, '').
				gsub( /::/, '-' ).
				gsub( /([a-z])([A-Z])/, "\\1-\\2" ).
				gsub( /[^-\w]+/, '' ).
				downcase
			nodeclass << "-node" unless /-node$/.match( nodeclass )

			return nodeclass
		end


	end # class Node


	### The plain-content node object class.  Instances of this class are
	### nodes in a syntax tree which represents the textual contents of an
	### Arrow::Template object.
	class TextNode < Arrow::Template::Node


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
		def is_rendering_node?
			true
		end


		### Return the node as a String.
		def to_s
			self.body.to_s
		end


		### Return an HTML fragment that can be used to represent the node
		### symbolically in a web-based introspection interface.
		def to_html
			super { self.escape_html(@body) }
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
			[ template.render_comment( self.to_s ) ]
		end


		### Return an HTML fragment that can be used to represent the node
		### symbolically in a web-based introspection interface.
		def to_html
			super { self.escape_html(self.to_s) }
		end

	end # class CommentNode


	### The abstract directive superclass. Instances of derivatives of this
	### class define template behaviour and content.
	class Directive < Arrow::Template::Node
		include PluginFactory


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Return the list of subdirectories to search for template nodes.
		def self::derivativeDirs
			["arrow/template"]
		end


		### Factory method: overridden from PluginFactory.create to
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
			self.parse_directive_contents( parser, state )
		end


		######
		public
		######

		### Render the directive as a String and return it.
		def render( template, scope )
			rary = []
			rary << template.render_comment( self.inspect ) if
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
				callback = Proc.new
				super( &callback )
			else
				fields = instance_variables.sort.collect {|ivar|
					val = instance_variable_get( ivar )
					%q{<span class="ivar"><em>%s:</em> %s</span>} %
						[ ivar, self.escape_html(val) ]
				}

				super { fields.join(", ") }
			end
		end


		#########
		protected
		#########

		### Parse the contents of the directive. This is a no-op for this class;
		### it's here to allow delegation of this task to subclasses.
		def parse_directive_contents( parser, state )
		end


	end # class Directive


	### The attribute directive superclass. Attribute directives are those that
	### present an exterior interface to the controlling system for
	### message-passing and content-injection (e.g., <?attr?>, <?set?>,
	### <?config?>, etc.)
	class AttributeDirective < Arrow::Template::Directive


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Returns +true+ for classes that support a prepended format. (e.g.,
		### <?call "%15s" % foo ?>).
		def self::allows_format?
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
		def is_rendering_node?
			true
		end


		### Try to pre-render any attributes which correspond to this node.
		def before_rendering( template )
			if attrib = template[ self.name ]
				# self.log.debug "  got %s attribute in #before_rendering for %p" %
					# [ attrib.class.name, self.name ]

				if attrib.respond_to?( :before_rendering )
					# self.log.debug "  pre-rendering attribute %p" % [attrib]
					attrib.before_rendering( template )
				elsif attrib.respond_to?( :each )
					# self.log.debug "  iterating over attribute %p" % [attrib]
					attrib.each do |obj|
						obj.before_rendering if obj.respond_to?( :before_rendering )
					end
				end
			else
				# No-op
				# self.log.debug "  no value for node %p in #before_rendering" %
					# self.name
			end
		end


		### Render the directive node's contents as a String and return it.
		def render( template, scope )
			# self.log.debug "Rendering %p" % self
			rary = super

			rary.push( *(self.render_contents( template, scope )) )
			return rary
		end


		### Return a human-readable version of the object suitable for debugging
		### messages.
		def inspect
			%Q{<%s %s%s (Format: %p)>} % [
				@type.capitalize,
				@name,
				@methodchain.strip.empty? ? "" : @methodchain,
				@format,
			]
		end


		### Return an HTML fragment that can be used to represent the node
		### symbolically in a web-based introspection interface.
		def to_html
			html = ''
			if @format
				html << %q{"%s" %% } % self.escape_html( @format )
			end
			html << %q{<strong>#%s</strong>} % @name
			if @methodchain
				html << self.escape_html( @methodchain )
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
		### identifier, then an optional methodchain attached to the identifier.
		def parse_directive_contents( parser, state )
			super

			# Look for a format
			if self.class.allows_format?
				if fmt = parser.scan_for_quoted_string( state )
					state.scanner.skip( /\s*%\s*/ ) or
						raise Arrow::ParseError, "Format missing modulus operator?"
					@format = fmt[1..-2]
					#self.log.debug "Found format %p" % @format
				else
					#self.log.debug "No format string"
					@format = nil
				end
			end

			# Look for the identifier
			@name = parser.scan_for_identifier( state ) or
				raise Arrow::ParseError, "missing or malformed indentifier"
			#self.log.debug "Set name of %s to %p" %
			#	[ self.class.name, @name ]

			# Now pick up the methodchain if there is one
			@methodchain = parser.scan_for_methodchain( state )

			return true
		end


		### Render the contents of the node
		def render_contents( template, scope )
			return self.call_methodchain( template, scope )
		end


		### Build a Proc object that encapsulates the execution necessary to
		### render the directive.
		def build_rendering_proc( template, scope )
			return nil if self.format.nil? && self.methodchain.nil?

			if self.format
				code = %(Proc.new {|%s| "%s" %% %s%s}) % 
					[ self.name, self.format, self.name, self.methodchain ]
			else
				code = "Proc.new {|%s| %s%s}" %
					[ self.name, self.name, self.methodchain ]
			end
			code.untaint

			#self.log.debug "Rendering proc code is: %p" % code
			desc = "[%s (%s): %s]" %
				[ self.class.name, __FILE__, code ]

			return eval( code, scope.get_binding, desc, __LINE__ )
		end


		### Call the node's methodchain, if any, passing the associated
		### attribute as the first argument and any additional +args+ as second
		### and succeeding arguments. Returns the results of the call.
		def call_methodchain( template, scope, *args )
			chain = self.build_rendering_proc( template, scope )
			# self.log.debug "Rendering proc is: %p" % chain

			# self.log.debug "Fetching attribute %p of template %p" %
				# [ self.name, template ]
			attribute = template.send( self.name )
			# self.log.debug "Attribute to be rendered (%s) is: %p" %
				# [ self.name, attribute ]

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
		def is_rendering_node?
			false
		end


		### Install the behaviour defined by the directive and its subnodes
		### into the given +template+ object. This by default just installs
		### each of its subnodes.
		def add_to_template( template )
			super
			self.subnodes.each do |node|
				template.install_node( node )
			end
		end


		### Return a human-readable version of the object suitable for debugging
		### messages.
		def inspect
			%Q{<%s %s%s: %p>} % [
				@type.capitalize,
				@name,
				@methodchain.strip.empty? ? "" : @methodchain,
				@subnodes,
			]
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
			nodeclass = self.css_class

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
		def parse_directive_contents( parser, state )
			super

			# Let subclasses implement further inner-tag parsing if they want
			# to.
			if block_given?
				rval = yield( parser, state )
				return nil if !rval
			end

			# Put the pointer after the closing tag 
			parser.scan_for_tag_ending( state ) or
				raise Arrow::ParseError, "couldn't find tag end for '#@name'"

			# Parse the content between this directive and the next <?end?>.
			@subnodes.replace( parser.scan_for_nodes(state, type, self) )

			return true
		end


		### Use the contents of the associated attribute to render the
		### receiver's subnodes in the specified +scope+.
		def render_contents( template, scope )
			res = super
			self.render_subnodes( res, template, scope )
		end


		### Render each of the directive's bracketed nodes with the given
		### +item+, +template+, and evaluation +scope+.
		def render_subnodes( item, template, scope )
			template.with_overridden_attributes( scope, self.name => item ) do |template|
				template.render( @subnodes, scope )
			end
		end

	end # class BracketingDirective


	### Mixin which adds the notion of boolean evaluability to a directive.
	module ConditionalDirective


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		######
		public
		######

		### Returns +true+ for nodes which generate output themselves (as
		### opposed to ones which generate output through subnodes). This is
		### used for eliding blank lines from the node tree.
		def is_rendering_node?
			false
		end


		### Returns +true+ if this Directive, in the context of the given
		### +template+ (an Arrow::Template) and +scope+ (a Binding object),
		### should be considered "true".
		def evaluate( template, scope )
			rval = self.call_methodchain( template, scope )

			#self.log.debug "Methodchain evaluated to %s: %p" %
			#	[ rval ? "true" : "false", rval ]
			return rval ? true : false
		end

	end # module ConditionalDirective

end # class Arrow::Template


