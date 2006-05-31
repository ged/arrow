#!/usr/bin/ruby
# 
# This file contains the Arrow::Template class, instances of which are used to
# generate X(HT)ML output for Arrow applications.
# 
# == Synopsis
# 
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
# Please see the file docs/COPYRIGHT for licensing details.
#

require 'forwardable'

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/object'
require 'arrow/utils'


### The default template class for Arrow.
class Arrow::Template < Arrow::Object
	extend Forwardable

	require 'arrow/template/parser'
	require 'arrow/template/nodes'
	require 'arrow/template/iterator'

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Configuration defaults. Valid members are the same as those listed for
	# the +config+ item of the #new method.
	Defaults = {
		:parserClass			=> Arrow::Template::Parser,
		:elideDirectiveLines	=> true,
		:debuggingComments		=> false,
		:commentStart			=> '<!-- ',
		:commentEnd				=> ' -->',
		:strictAttributes		=> false,
	}
	Defaults.freeze

	# A Hash which specifies the default renderers for different classes of
	# objects.
	DefaultRenderers = {
		Arrow::Template	=> lambda {|subtempl,templ|
			subtempl.render( nil, nil, templ )
		},
		::Object		=> :to_s,
		::Array			=> lambda {|ary,tmpl|
			tmpl.render_objects(*ary)
		},
		::Hash			=> lambda {|hsh,tmpl|
			hsh.collect do |k,v| tmpl.render_objects(k, ": ", v) end
		},
		::Method		=> lambda {|meth,tmpl|
			tmpl.render_objects( meth.call )
		},
		::Exception		=> lambda {|err,tmpl|
			tmpl.render_comment "%s: %s: %s" % [
				err.class.name,
				err.message,
				err.backtrace ? err.backtrace[0] : "Stupid exception with no backtrace.",
			]
		},
	}


	### A class for objects which contain the execution space of all the
	### code in a single rendering of a template.
	class RenderingScope < Arrow::Object

		### Create a new RenderingScope object with the specified
		### definitions +defs+. Each key => value pair in +defs+ will become
		### singleton accessors on the resulting object.
		def initialize( defs={} )
			@definitions = []
			self.add_definition_set( defs )
		end


		######
		public
		######

		# The stack of definition contexts being represented by the scope.
		#attr_reader :definitions


		### Fetch the Binding object for the RenderingScope.
		def get_binding; binding; end


		### Add the specified definitions +defs+ to the object.
		def add_definition_set( defs )
			#self.log.debug "adding definition set: %p" % [ defs ]
			@definitions.push( defs )

			defs.each do |name,val|
				raise ScopeError, "Cannot override @definitions" if
					name == 'definitions'
				@definitions.last[ name ] = val

				# Add accessor and ivar for the definition if it doesn't
				# already have one.
				unless self.respond_to?( name.to_s.intern )
					#self.log.debug "Adding accessor for %s" % name
					(class << self; self; end).instance_eval {
						attr_accessor name.to_s.intern
					}
				else
					#self.log.debug "Already have an accessor for '#{name}'"
				end

				self.instance_variable_set( "@#{name}", defs[name] )
			end
		end


		### Remove the specified definitions +defs+ from the object. Using
		### a definition so removed after this point will raise an error.
		def remove_definition_set
			#self.log.debug "Removing definition set from stack of %d frames" %
			#	@definitions.nitems
			defs = @definitions.pop
			#self.log.debug "Removing defs: %p, %d frames left" % 
			#	[ defs, @definitions.nitems ]

			defs.keys.each do |name|
				next if name == 'definitions'

				# If there was already a definition in effect with the same
				# name in a previous scope, fetch it so we can play with it.
				previousSet = @definitions.reverse.find {|set| set.key?(name)}
				#self.log.debug "Found previousSet %p for %s in scope stack of %d frames" %
				#	[ previousSet, name, @definitions.nitems ]

				# If none of the previous definition sets had a definition
				# with the same name, remove the accessor and the ivar
				unless previousSet
					#self.log.debug "Removing definition '%s' entirely" % name
					(class << self; self; end).module_eval {
						remove_method name.to_s.intern
					}
					remove_instance_variable( "@#{name}" )

				# Otherwise just reset the ivar to the previous value
				else
					#self.log.debug "Restoring previous def for '%s'" % name
					self.instance_variable_set( "@#{name}", previousSet[name] )
				end
			end

		end


		### Override the given definitions +defs+ for the duration of the
		### given block. After the block exits, the original definitions
		### will be restored.
		def override( defs ) # :yields: receiver
			begin
				#self.log.debug "Before adding definitions: %d scope frame/s. Last: %p" %
				#	[ @definitions.nitems, @definitions.last.keys ]
				self.add_definition_set( defs )
				#self.log.debug "After adding definitions: %d scope frame/s. Last: %p" % 
				#	[ @definitions.nitems, @definitions.last.keys ]
				yield( self )
			ensure
				self.remove_definition_set
			end
		end

	end # class RenderingScope



	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	# The Array of directories the template class searches for template
	# names given to #load.
	@load_path = %w{.}
	class << self
		attr_accessor :load_path
	end


	### Load a template from a file.
	def self::load( source, path=[], cache={} )

		# Find the file on either the specified or default path
		path = self.load_path if path.empty?
		Arrow::Logger[self].debug "Searching for template '%s' in %d directories" % [ source, path.size ]
		filename = self.find_file( source, path )
		Arrow::Logger[self].debug "Found '%s'; cache contains %d entries" % [ filename, cache.size ]

		# Use the cached version if the caller passed one in and it exists.
		if cache.include?( filename ) && !cache[ filename ].nil?
			Arrow::Logger[self].debug "Cloning cached object for %p" % [ filename ]
			obj = cache[ filename ].clone
		else
			Arrow::Logger[self].debug "No cached version: Loading %p anew" % [ filename ]
			source = File.read( filename )
			source.untaint

			# Create a new template object, set its path and filename, then tell it
			# to parse the loaded source to define its behaviour.
			obj = cache[ filename ] = new()
			obj._file = filename
			obj._load_path.replace( path )
			obj.parse( source )
		end

		Arrow::Logger[self].debug "Returning template object. Cache has %d entries" % 
			[ cache.size ]
		return obj
	end


	### Find the specified +file+ in the given +path+ (or the Template
	### class's #load_path if not specified).
	def self::find_file( file, path=[] )
		raise TemplateError, "Filename #{file} is tainted." if
			file.tainted?

		filename = path.
			collect {|dir| File.expand_path(file, dir).untaint }.
			find {|fn| File.file?(fn) }
		raise Arrow::TemplateError,
			"Template '%s' not found. Search path was %p" %
			[ file, path ] unless filename

		return filename
	end


	### Create an attr_reader method for the specified +sym+, but one which
	### will look for instance variables with any leading underbars removed.
	def self::attr_underbarred_reader( sym )
		ivarname = '@' + sym.to_s.gsub( /^_+/, '' )
		define_method( sym ) {
			self.instance_variable_get( ivarname )
		}
	end


	### Create an attr_accessor method for the specified +sym+, but one which
	### will look for instance variables with any leading underbars removed.
	def self::attr_underbarred_accessor( sym )
		ivarname = '@' + sym.to_s.gsub( /^_+/, '' )
		define_method( sym ) {
			self.instance_variable_get( ivarname )
		}
		define_method( "#{sym}=" ) {|arg|
			self.instance_variable_set( ivarname, arg )
		}
	end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new template object with the specified +content+ (a String)
	### and +config+ hash. The +config+ can contain one or more of the
	### following keys:
	###
	### [<b>:parserClass</b>]
	###   The class object that will be instantiated to parse the template
	###   text into nodes. Defaults to Arrow::Template::Parser.
	### [<b>:elideDirectiveLines</b>]
	###   If set to a +true+ value, lines of the template which contain only
	###   whitespace and one or more non-rendering directives will be
	###   discarded from the rendered output.
	### [<b>:debuggingComments</b>]
	###   If set to a +true+ value, nodes which are set up to do so will
	###   insert a comment with debugging information immediately before
	###   their rendered output.
	### [<b>:commentStart</b>]
	###   The String which will be prepended to all comments rendered in the
	###   output. See #render_comment.
	### [<b>:commentEnd</b>]
	###   The String which will be appended to all comments rendered in the
	###   output. See #render_comment.
	### [<b>:strictAttributes</b>]
	###   If set to a +true+ value, method calls which don't match
	###   already-extant attributes will result in NameErrors. This is
	###   +false+ by default, which causes method calls to generate
	###   attributes with the same name.
	def initialize( content=nil, config={} )
		@config = Defaults.merge( config, &Arrow::HashMergeFunction )
		@renderers = DefaultRenderers.dup
		@attributes = {}
		@syntax_tree = []
		@source = content
		@file = nil
		@creation_time = Time.now
		@load_path = self.class.load_path.dup

		@enclosing_template = nil

		case content
		when String
			self.parse( content )
		when Array
			self.install_syntax_tree( content )
		when NilClass
			# No-op
		else
			raise TemplateError,
				"Can't handle a %s as template content" % content.class.name
		end
	end


	### Initialize a copy of the +original+ template object.
	def initialize_copy( original )
		super
		
		@attributes = {}
		tree = original._syntax_tree.collect {|node| node.clone}
		self.install_syntax_tree( tree )
	end


	######
	public
	######

	# Square-bracket methods access template attributes
	def_delegators :@attributes, :[], :[]=

	# The Hash of "attributes" for the template -- data fields which hold
	# values which can be accessed by the template's nodes for rendering.
	attr_underbarred_reader :_attributes

	# The Array of first-level nodes which make up the AST of the template.
	attr_underbarred_reader :_syntax_tree

	# The template's configuration
	attr_underbarred_reader :_config

	# The Hash of rendering Procs, Methods, or Symbols (which specify a
	# method on the rendered object) which are used to render objects in the
	# template's node contents.
	attr_underbarred_reader :_renderers

	# The source file for the template, if any
	attr_underbarred_accessor :_file

	# The template source
	attr_underbarred_accessor :_source

	# The load path used when the template was loaded. This is the path that
	# will be used to load any subordinate resources (eg., includes).
	attr_underbarred_accessor :_load_path

	# The Time that the template object was created
	attr_underbarred_accessor :_creation_time

	# The template which contains this one (if any) during a render.
	attr_underbarred_accessor :_enclosing_template



	### Return the approximate size of the template, in bytes. Used by
	### Arrow::Cache for size thresholds.
	def memsize
		@source ? @source.length : 0
	end


	### Parse the given template source (a String) and put the resulting
	### nodes into the template's syntax_tree.
	def parse( source )
		@source = source
		parserClass = @config[:parserClass]
		tree = parserClass.new( @config ).parse( source, self )

		#self.log.debug "Parse complete: syntax tree is: %p" % tree
		return self.install_syntax_tree( tree )
	end


	### Install a new syntax tree in the template object, replacing the old one,
	### if any.
	def install_syntax_tree( tree )
		@syntax_tree = tree
		@syntax_tree.each do |node| node.add_to_template(self) end
	end


	### Install the given +node+ into the template object.
	def install_node( node )
		#self.log.debug "Installing a %s %p" % [node.type, node]

		if node.respond_to?( :name ) && node.name
			unless @attributes.key?( node.name )
				#self.log.debug "Installing an attribute for a node named %p" % node.name
				@attributes[ node.name ] = nil
				self.add_attribute_accessor( node.name.intern )
				self.add_attribute_mutator( node.name.intern )
			else
				#self.log.debug "Already have a attribute named %p" % node.name
			end
		end
	end


	### Returns +true+ if the source file from which the template was read
	### has been modified since the receiver was instantiated. Always
	### returns +false+ if the template wasn't loaded from a file.
	def changed?
		return false unless @file

		if File.exists?( @file )
			self.log.debug "Comparing creation time '%s' with file mtime '%s'" %
				[ @creation_time, File.mtime(@file) ]
			rval = File.mtime( @file ) > @creation_time
		end

		self.log.debug "Template file '%s' has %s" %
			[ @file, rval ? "changed" : "not changed" ]
		return rval
	end


	### Render the template to text and return it as a String. If called with an
	### Array of +nodes+, the template will render them instead of its own
	### syntax_tree. If given a scope (a Module object), a Binding of its
	### internal state it will be used as the context of evaluation for the
	### render. If not specified, a new anonymous Module instance is created for
	### the render. If a +enclosing_template+ is given, make it available during
	### rendering for variable-sharing, etc. Returns the results of each nodes'
	### render joined together with the default string separator (+$,+).
	def render( nodes=nil, scope=nil, enclosing_template=nil )
		oldSuper = @enclosing_template
		@enclosing_template = enclosing_template

		# If no nodes were given, fetch a prepped copy of this template's
		# syntax tree
		nodes ||= self.get_prepped_nodes

		# Set up a rendering scope if none was specified
		scope ||= self.make_rendering_scope

		# Catenate the results of rendering each node
		rval = []
		nodes.each do |node|
			#self.log.debug "Rendering a %s: %p" % 
			#	[ node.class.name, node ]
			begin
				rval << node.render( self, scope )
			rescue ::Exception => err
				rval << err
			end
		end

		return self.render_objects( *rval )
	ensure
		@enclosing_template = oldSuper
	end
	alias_method :to_s, :render


	### Create an anonymous module to act as a scope for any evals that take
	### place during a single render.
	def make_rendering_scope
		scope = RenderingScope.new( @attributes )
		return scope
	end


	### Render the specified object into text.
	def render_objects( *objs )
		objs.collect do |obj|
			rval = nil
			key = (@renderers.keys & obj.class.ancestors).sort {|a,b| a <=> b}.first

			if key
				case @renderers[ key ]
				when Proc, Method
					rval = @renderers[ key ].call( obj, self )
				when Symbol
					rval = obj.send( @renderers[ key ] )
				else
					raise TypeError, "Unknown renderer type '%s' for %p" %
						[ @renderers[key], obj ]
				end
			else
				rval = obj.to_s
			end
		end.join('')
	end


	### Render the given +message+ as a comment as specified by the template
	### configuration.
	def render_comment( message )
		comment = "%s%s%s\n" % [
			@config[:commentStart],
			message,
			@config[:commentEnd],
		]
		#self.log.debug "Rendered comment: %s" % comment
		return comment
	end


	### Call the given +block+, overriding the contents of the template's attributes
	### and the definitions in the specified +scope+ with those from the pairs in 
	### the given +hash+.
	def with_overridden_attributes( scope, hash )
		oldvals = {}
		begin
			hash.each do |name, value|
				#self.log.debug "Overriding attribute %s with value: %p" %
				#	[ name, value ]
				oldvals[name] = @attributes.key?( name ) ? @attributes[ name ] : nil
				@attributes[ name ] = value
			end
			scope.override( hash ) do
				yield( self )
			end
		ensure
			oldvals.each do |name, value|
				#self.log.debug "Restoring old value: %s for attribute %p" %
				#	[ name, value ]
				@attributes.delete( name )
				@attributes[ name ] = oldvals[name] if oldvals[name]
			end
		end
	end



	#########
	protected
	#########

	### Returns the syntax tree with its nodes prepped in accordance with
	### the template's configuration.
	def get_prepped_nodes
		tree = @syntax_tree.dup

		# Make a flat list of all nodes
		nodes = tree.collect {|node| node.to_a}.flatten

		# Elide directive lines. Match node lists like:
		#   <TextNode> =~ /\n\s*$/
		#   <NonRenderingNode>*
		#   <TextNode> =~ /^\n/
		# removing one "\n" from the tail of the leading textnode and the
		# head of the trailing textnode. Trailing textnode can also be a
		# leading textnode for another series.

		if @config[:elideDirectiveLines]
			nodes.each_with_index do |node,i|
				#self.log.debug "Examining node #%d: %p" % [ i, node ]
				leadingNode = nodes[i-1]

				# If both the leading node and the current one match the
				# criteria, look for a trailing node.
				if i.nonzero? && leadingNode.is_a?( TextNode ) &&
						leadingNode =~ /\n\s*$/s
					#self.log.debug "Found candidate leading node: %p" % leadingNode

					# Find the trailing node. Abandon the search on any
					# rendering directive or text node that 
					trailingNode = nodes[i..-1].find do |node|
						if node.rendering?
							#self.log.debug "Stopping search: Found a rendering node."
							break nil
						end

						node.is_a?( TextNode ) && node =~ /^\n/
					end

					if trailingNode
						leadingNode.body.sub!( /\n\s*$/, '' )
						# trailingNode.body.sub!( /^\n/, '' )
					else
						#self.log.debug "No trailing node. Skipping"
					end
				end
			end
		end

		return tree
	end


	### Autoload accessor/mutator methods for attributes.
	def method_missing( sym, *args, &block )
		name = sym.to_s.gsub( /=$/, '' )
		super unless @attributes.key?( name ) || !@config[:strictAttributes]

		#self.log.debug "Autoloading for #{sym}"

		# Mutator
		if /=$/ =~ sym.to_s
			#self.log.debug "Autoloading mutator %p" % sym
			self.add_attribute_mutator( sym )
		# Accessor
		else
			#self.log.debug "Autoloading accessor %p" % sym
			self.add_attribute_accessor( sym )
		end

		# Don't use #send to avoid infinite recursion in case method
		# definition has failed for some reason.
		self.method( sym ).call( *args )
	end


	### Add a singleton accessor (getter) method for accessing the attribute
	### specified by +sym+ to the receiver.
	def add_attribute_accessor( sym )
		name = sym.to_s.sub( /=$/, '' )

		code = %Q{
			def self.#{name}
				@attributes[#{name.inspect}]
			end
		}

		# $stderr.puts "Auto-defining accessor for #{name}: #{code}"
		eval( code, nil, "#{name} [Auto-defined]", __LINE__ )
	end


	### Add a singleton mutator (setter) method for accessing the attribute
	### specified by +sym+ to the receiver.
	def add_attribute_mutator( sym )
		name = sym.to_s.sub( /=$/, '' )

		code = %Q{
			def self.#{name}=( arg )
				@attributes[ #{name.inspect} ] = arg
			end
		}

		# $stderr.puts "Auto-defining mutator for #{name}: #{code}"
		eval( code, nil, "#{name}= [Auto-defined]", __LINE__ )
	end

end # class Arrow::Template

