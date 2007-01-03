#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::IncludeDirective class, a derivative of
# Arrow::Template::Directive. This is the class which defines the
# behaviour of the 'include' template directive.
# 
# == Syntax
#
#   <!-- Include a subtemplate directly -->
#   <?include subtemplate.tmpl ?>
#
#   <!-- Include a subtemplate as a callable sub-entity -->
#   <?include subtemplate.tmpl as sub ?>
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

### The class which defines the behaviour of the 'include'
### template directive.
class Arrow::Template::IncludeDirective < Arrow::Template::Directive # :nodoc:
	include Arrow::Template::Parser::Patterns

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$
	


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
	def add_to_template( template )
		#self.log.debug "Installing an include's subnodes"

		if @identifier
			template.install_node( self )
			template.send( "#{@identifier}=", @subtemplate )
			targetTemplate = @subtemplate
		else
			targetTemplate = template
		end

		@nodes.each do |node|
			targetTemplate.install_node( node )
		end
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
		nodeclass = self.css_class

		if @subtemplate
			subtree = @subtemplate._syntax_tree
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
	def parse_directive_contents( parser, state )
		filename = parser.scan_for_pathname( state ) or
			raise Arrow::ParseError, "No filename found for 'include'"
		filename.untaint

		state.scanner.skip( WHITESPACE )
		if state.scanner.scan( /\bas\b/i )
			@identifier = parser.scan_for_identifier( state )
		end

		# Try to do the include. Handle errors ourselves since this happens
		# during parse time.
		begin
			#self.log.debug "Include stack is: ", state[:includeStack]

			# Catch circular includes
			if state[:includeStack].include?( filename )
				raise Arrow::TemplateError, "Circular include: %s -> %s" %
					[ state[:includeStack].join(" -> "), filename ]

			# Parse the included file into nodes, passing the state from
			# the current parse into the subparse.
			else
				initialData = state.data.dup
				initialData[:includeStack].push filename
				
				load_path = state.template._load_path
				#self.log.debug "Load path from including template is: %p" %
				#	load_path
				path = Arrow::Template.find_file( filename, load_path )
				content = File.read( path )
				content.untaint

				#self.log.debug "initialData is: %p" % initialData
				@nodes = parser.parse( content, state.template, initialData )
				initialData[:includeStack].pop
			end

		# Some errors just turn into comment nodes
		# :TODO: Make this configurable somehow?
		rescue Arrow::TemplateError, IOError => err
			msg = "#{err.class.name}: Include #{filename}: #{err.message}"
			@nodes = [ Arrow::Template::CommentNode.new(msg) ]
		end

		# If the directive has an "as <id>" part, create the subtemplate
		# that will be associated with that identifier.
		if @identifier
			@subtemplate = Arrow::Template.new( @nodes, state.template._config )
		end

		return true
	end


end # class Arrow::Template::IncludeDirective
