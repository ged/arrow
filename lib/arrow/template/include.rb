#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::IncludeDirective class, a derivative of
# Arrow::Template::Directive. This is the class which defines the
# behaviour of the 'include' template directive.
# 
# == Syntax
#
# <!-- Include a subtemplate directly -->
# <?include subtemplate.tmpl ?>
#
# <!-- Include a subtemplate as a callable sub-entity -->
# <?include subtemplate.tmpl as sub ?>
#
# == Example
# If 'subtemplate.tmpl' contains:
#   <?attr foo?>
# and the main template contains:
#   <?include subtemplate.tmpl?>
#   <?include subtemplate.tmpl as sub?>
# and the code (+template+ is the Template object) looks like:
#   template.foo = "argle"
#   template.sub.foo = "bargle"
# the template will render as:
#   argle
#   bargle
#
# == Rcsid
# 
# $Id: include.rb,v 1.6 2004/01/20 05:21:05 deveiant Exp $
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

	### The class which defines the behaviour of the 'include'
	### template directive.
	class IncludeDirective < Arrow::Template::Directive
		include Arrow::Template::Parser::Patterns

		# CVS version string
		Version = /([\d\.]+)/.match( %q{$Revision: 1.6 $} )[1]

		# CVS Id string
		Rcsid = %q$Id: include.rb,v 1.6 2004/01/20 05:21:05 deveiant Exp $



		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Initialize a new IncludeDirective object.
		def initialize( type, parser, state ) # :notnew:
			@nodes			= nil
			@identifier		= nil
			@subtemplate	= nil

			state[:includeStack] ||= []
			super
		end


		######
		public
		######

		# The identifier associated with an include that has an 'as <name>'
		# part.
		attr_accessor :identifier
		alias_method :name, :identifier
		alias_method :name=, :identifier=

		# The template object associated with an include that has an 'as <name>'
		# part.
		attr_accessor :subtemplate


		### Add the nodes that were included to the given +template+ object.
		def addToTemplate( template )
			#self.log.debug "Installing an include's subnodes"

			if @identifier
				template.installNode( self )
				template.send( "#{@identifier}=", @subtemplate )
				targetTemplate = @subtemplate
			else
				targetTemplate = template
			end

			@nodes.each {|node|
				targetTemplate.installNode( node )
			}
		end


		### Render the include.
		def render( template, scope )
			rary = super

			# Render the included nodes
			if @subtemplate
				#self.log.debug "Rendering an include's subtemplate"
				rary.push( *(@subtemplate.render) )
			else
				#self.log.debug "Rendering an include's subnodes"
				rary.push( *(template.render( @nodes, scope )) )
			end

			return rary
		end


		### Return an HTML fragment that can be used to represent the node
		### symbolically in a web-based introspection interface.
		def to_html
			nodeclass = self.cssClass

			if @subtemplate
				subtree = @subtemplate._syntaxTree
				html = ''
				html << %q{<strong>#%s</strong> } % @identifier
				html <<
					%q{<div class="node-subtemplate %s-node-subtemplate">
					<div class="node-subtemplate-head %s-node-subtemplate-head"
					>Subtemplate</div>%s</div>} % [
						nodeclass, nodeclass,
						subtree.collect {|node| node.to_html}.join(''),
					]

				super { html }
			else
				super {
					%q{<div class="node-subtree %s-node-subtree">
					<div class="node-subtree-head %s-node-subtree-head"
					>Subnodes</div>%s</div>} % [
						nodeclass, nodeclass,
						@nodes.collect {|node| node.to_html}.join
					]
				}
			end
		end


		#########
		protected
		#########
		
		### Parse the contents of the directive, loading the specified file into
		### the scanner, if possible.
		def parseDirectiveContents( parser, state )
			filename = parser.scanForPathname( state ) or
				raise Arrow::ParseError, "No filename found for 'include'"
			filename.untaint

			state.scanner.skip( WHITESPACE )
			if state.scanner.scan( /\bas\b/i )
				@identifier = parser.scanForIdentifier( state )
			end

			# Try to do the include. Handle errors ourselves since this happens
			# during parse time.
			begin
				#self.log.debug "Include stack is: ", state[:includeStack]

				# Catch circular includes
				if state[:includeStack].include?( filename )
					raise TemplateError, "Circular include: %s -> %s" %
						[ state[:includeStack].join(" -> "), filename ]

				# Parse the included file into nodes, passing the state from
				# the current parse into the subparse.
				else
					initialData = state.data.dup
					initialData[:includeStack].push filename
					
					loadPath = state.template._loadPath
					#self.log.debug "Load path from including template is: %p" %
					#	loadPath
					path = Arrow::Template::findFile( filename, loadPath )
					content = File::read( path )
					content.untaint

					#self.log.debug "initialData is: %p" % initialData
					@nodes = parser.parse( content, state.template, initialData )
				end

			# Some errors just turn into comment nodes
			# :TODO: Make this configurable somehow?
			rescue TemplateError, IOError => err
				msg = "#{err.class.name}: Include #{filename}: #{err.message}"
				@nodes = [ Arrow::Template::CommentNode::new(msg) ]
			end

			# If the directive has an "as <id>" part, create the subtemplate
			# that will be associated with that identifier.
			if @identifier
 				@subtemplate = Arrow::Template::new( @nodes, state.template._config )
			end

			return true
		end


	end # class IncludeDirective

end # class Template
end # module Arrow


