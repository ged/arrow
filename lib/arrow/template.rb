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

module Arrow

	### The default template class for Arrow.
	class Template < Arrow::Object
		extend Forwardable

		require 'arrow/template/parser'
		require 'arrow/template/nodes'
		require 'arrow/template/iterator'

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

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
				tmpl.renderObjects(*ary)
			},
			::Hash			=> lambda {|hsh,tmpl|
				hsh.collect do |k,v| tmpl.renderObjects(k, ": ", v) end
			},
			::Method		=> lambda {|meth,tmpl|
				tmpl.renderObjects( meth.call )
			},
			::Exception		=> lambda {|err,tmpl|
				tmpl.renderComment "%s: %s: %s" % [
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
				self.addDefinitionSet( defs )
			end


			######
			public
			######

			# The stack of definition contexts being represented by the scope.
			#attr_reader :definitions


			### Fetch the Binding obejct for the RenderingScope.
			def getBinding; binding; end


			### Add the specified definitions +defs+ to the object.
			def addDefinitionSet( defs )
				#self.log.debug "adding definition set: %p" % [ defs ]
				@definitions.push( defs )

				defs.each {|name,val|
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
				}
			end


            ### Remove the specified definitions +defs+ from the object. Using
            ### a definition so removed after this point will raise an error.
            def removeDefinitionSet
				#self.log.debug "Removing definition set from stack of %d frames" %
				#	@definitions.nitems
                defs = @definitions.pop
				#self.log.debug "Removing defs: %p, %d frames left" % 
				#	[ defs, @definitions.nitems ]

                defs.keys.each {|name|
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
				}

            end


			### Override the given definitions +defs+ for the duration of the
			### given block. After the block exits, the original definitions
			### will be restored.
			def override( defs ) # :yields: receiver
				begin
					#self.log.debug "Before adding definitions: %d scope frame/s. Last: %p" %
					#	[ @definitions.nitems, @definitions.last.keys ]
					self.addDefinitionSet( defs )
					#self.log.debug "After adding definitions: %d scope frame/s. Last: %p" % 
					#	[ @definitions.nitems, @definitions.last.keys ]
					yield( self )
				ensure
					self.removeDefinitionSet
				end
			end

		end # class RenderingScope



		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		# The Array of directories the template class searches for template
		# names given to #load.
		@loadPath = %w{.}
		class << self
			attr_accessor :loadPath
		end


		### Load a template from a file.
		def self::load( source, path=[] )
			path = self.loadPath if path.empty?
			filename = self.findFile( source, path )
			source = File::read( filename )
			source.untaint

			obj = new( source )
			obj._file = filename
			obj._loadPath.replace( path )

			return obj
		end


		### Find the specified +file+ in the given +path+ (or the Template
		### class's #loadPath if not specified).
		def self::findFile( file, path=[] )
			raise TemplateError, "Filename #{file} is tainted." if
				file.tainted?

			filename = path.
				collect {|dir| File::expand_path(file, dir).untaint }.
				find {|fn| File::file?(fn) }
			raise TemplateError,
				"Template '%s' not found. Search path was %s" %
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
		###   output. See #renderComment.
		### [<b>:commentEnd</b>]
		###   The String which will be appended to all comments rendered in the
		###   output. See #renderComment.
		### [<b>:strictAttributes</b>]
		###   If set to a +true+ value, method calls which don't match
		###   already-extant attributes will result in NameErrors. This is
		###   +false+ by default, which causes method calls to generate
		###   attributes with the same name.
		def initialize( content=nil, config={} )
			@config = Defaults.merge( config, &Arrow::HashMergeFunction )
			@renderers = DefaultRenderers.dup
			@attributes = {}
			@syntaxTree = []
			@source = content
			@file = nil
			@creationTime = Time::now
			@loadPath = self.class.loadPath

			@superTemplate = nil

			case content
			when String
				self.parse( content )
			when Array
				@syntaxTree = content
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
			@syntaxTree.each {|node| node.addToTemplate(self) }
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
		attr_underbarred_reader :_syntaxTree

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
		attr_underbarred_accessor :_loadPath

		# The Time that the template object was created
		attr_underbarred_accessor :_creationTime

		# The template which contains this one (if any) during a render.
		attr_underbarred_accessor :_superTemplate
		


		### Return the approximate size of the template, in bytes. Used by
		### Arrow::Cache for size thresholds.
		def memsize
			@source.length
		end


		### Parse the given template source (a String) and put the resulting
		### nodes into the template's syntaxTree.
		def parse( source )
			parserClass = @config[:parserClass]
			@syntaxTree = parserClass::new( @config ).parse( source, self )

			#self.log.debug( "Parse complete: syntax tree is: #{@syntaxTree.inspect}" )

			@syntaxTree.each {|node| node.addToTemplate(self) }
		end


		### Install the given +node+ into the template object.
		def installNode( node )
			#self.log.debug "Installing a %s %p" % [node.type, node]

			if node.respond_to?( :name ) && node.name
				unless @attributes.key?( node.name )
					#self.log.debug "Installing a attribute for a node named %p" % node.name
					@attributes[ node.name ] = nil
					self.addAttributeAccessor( node.name.intern )
					self.addAttributeMutator( node.name.intern )
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
			
			if File::exists?( @file )
				self.log.debug "Comparing creation time '%s' with file mtime '%s'" %
					[ @creationTime, File::mtime(@file) ]
				rval = File::mtime( @file ) > @creationTime
			end
			
			self.log.debug "Template file '%s' has %s" %
				[ @file, rval ? "changed" : "not changed" ]
			return rval
		end


		### Render the template to text and return it as a String. If called
		### with an Array of +nodes+, the template will render them instead of
		### its own syntaxTree. If given a scope (a Module object), a
		### Binding of its internal state it will be used as the context of
		### evaluation for the render. If not specified, a new anonymous Module
		### instance is created for the render. Returns the results of each
		### nodes' render joined together with the default string separator
		### (+$,+).
		def render( nodes=nil, scope=nil, superTemplate=nil )
			oldSuper = @superTemplate
			@superTemplate = superTemplate

			# If no nodes were given, fetch a prepped copy of this template's
			# syntax tree
			nodes ||= self.getPreppedNodes

			# Set up a rendering scope if none was specified
			scope ||= self.makeRenderingScope

			# Catenate the results of rendering each node
			rval = []
			nodes.each {|node|
				#self.log.debug "Rendering a %s: %p" % 
				#	[ node.class.name, node ]
				begin
					rval << node.render( self, scope )
				rescue ::Exception => err
					rval << err
				end
			}

			return self.renderObjects( *rval )
		ensure
			@superTemplate = oldSuper
		end
		alias_method :to_s, :render


		### Create an anonymous module to act as a scope for any evals that take
		### place during a single render.
		def makeRenderingScope
			scope = RenderingScope::new( @attributes )
			return scope
		end


		### Render the specified object into text.
		def renderObjects( *objs )
			objs.collect {|obj|
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
			}.join('')
		end


		### Render the given +message+ as a comment as specified by the template
		### configuration.
		def renderComment( message )
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
		def withOverriddenAttributes( scope, hash )
			oldvals = {}
			begin
				hash.each {|name, value|
					#self.log.debug "Overriding attribute %s with value: %p" %
					#	[ name, value ]
					oldvals[name] = @attributes.key?( name ) ? @attributes[ name ] : nil
					@attributes[ name ] = value
				}
				scope.override( hash ) {
					yield( self )
				}
			ensure
				oldvals.each {|name, value|
					#self.log.debug "Restoring old value: %s for attribute %p" %
					#	[ name, value ]
					@attributes.delete( name )
					@attributes[ name ] = oldvals[name] if oldvals[name]
				}
			end
		end



		#########
		protected
		#########

		### Returns the syntax tree with its nodes prepped in accordance with
		### the template's configuration.
		def getPreppedNodes
			tree = @syntaxTree.dup
			nodes = tree.collect {|node| node.to_a}.flatten

			# Elide directive lines. Match node lists like:
			#   <TextNode> =~ /\n\s*$/
			#   <NonRenderingNode>*
			#   <TextNode> =~ /^\n/
			# removing one "\n" from the tail of the leading textnode and the
			# head of the trailing textnode. Trailing textnode can also be a
			# leading textnode for another series.

			### Commented because this probably isn't the best place to do this,
			### as this way only catches toplevel nodes. Need something that
			### does recursion or make the parser state do this on the fly.

			if @config[:elideDirectiveLines]
				nodes.each_with_index {|node,i|
					#self.log.debug "Examining node #%d: %p" % [ i, node ]
					leadingNode = nodes[i-1]
			
					# If both the leading node and the current one match the
					# criteria, look for a trailing node.
					if i.nonzero? && leadingNode.is_a?( TextNode ) &&
							leadingNode =~ /\n\s*$/s
						#self.log.debug "Found candidate leading node: %p" % leadingNode
			
						# Find the trailing node. Abandon the search on any
						# rendering directive or text node that 
						trailingNode = nodes[i..-1].find {|node|
							if node.rendering?
								#self.log.debug "Stopping search: Found a rendering node."
								break nil
							end

							node.is_a?( TextNode ) && node =~ /^\n/
						}
			
						if trailingNode
							leadingNode.body.sub!( /\n\s*$/, '' )
							# trailingNode.body.sub!( /^\n/, '' )
						else
							#self.log.debug "No trailing node. Skipping"
						end
					end
				}
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
				self.addAttributeMutator( sym )
			# Accessor
			else
				#self.log.debug "Autoloading accessor %p" % sym
				self.addAttributeAccessor( sym )
			end

			# Don't use #send to avoid infinite recursion in case method
			# definition has failed for some reason.
			self.method( sym ).call( *args )
		end


		### Add a singleton accessor (getter) method for accessing the attribute
		### specified by +sym+ to the receiver.
		def addAttributeAccessor( sym )
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
		def addAttributeMutator( sym )
			name = sym.to_s.sub( /=$/, '' )

			code = %Q{
				def self.#{name}=( arg )
					@attributes[ #{name.inspect} ] = arg
				end
			}
				
			# $stderr.puts "Auto-defining mutator for #{name}: #{code}"
			eval( code, nil, "#{name}= [Auto-defined]", __LINE__ )
		end

	end # class Template
end # module Arrow

