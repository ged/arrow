#!/usr/bin/env ruby
# 
# This file contains the Arrow::Template::RenderDirective class, a derivative of
# Arrow::Template::Directive. This is the class which defines the
# behaviour of the 'render' template directive.
# 
# === Syntax
#
#	<?render foo as bar in baz.tmpl ?>
# 
# == Subversion Id
# 
# $Id$
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

require 'arrow/template/nodes'
require 'arrow/template/parser'

### The class which defines the behaviour of the 'render' template directive.
class Arrow::Template::RenderDirective < Arrow::Template::AttributeDirective # :nodoc:
	include Arrow::Template::Parser::Patterns

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Parse tokens
	AS = /\s+as\s+/i
	IN = /in/i
	

	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Disallow formats
	def self::allows_format?; false; end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new RenderDirective object.
	def initialize( type, parser, state )
		@target = nil
		@subtemplate = nil

		state[:templateCache] ||= {}

		super
	end


	######
	public
	######

	# An Array of Regexp objects which match the names of attributes to be
	# rendered.
	attr_reader :subtemplate


	### Return a human-readable version of the object suitable for debugging
	### messages.
	def inspect
		%Q{<%s %s%s as %s in %s>} % [
			@type.capitalize,
			@name,
			@methodchain.strip.empty? ? "" : "." + @methodchain,
			@target,
			@subtemplate._file,
		]
	end



	#########
	protected
	#########

	### Parse the contents of the directive.
	def parse_directive_contents( parser, state )
		scanner = state.scanner
		
		@name = parser.scan_for_identifier( state, true ) or
			raise Arrow::ParseError, "missing or malformed identifier"

		# If there's an infix operator, the rest of the tag up to the 'as' is
		# the methodchain. Can't use the parser's
		# #scan_for_methodchain because it just scans the rest of the tag.
		if scanner.scan( INFIX )
			# If the 'infix' was actually the left side of an index operator,
			# include it in the methodchain.
			start = scanner.matched == "[" ? scanner.pos - 1 : scanner.pos

			# Find the end of the methodchain
			# :FIXME: This will screw up if the methodchain itself has an ' as ' in it.
			scanner.scan_until( AS ) or
				raise Arrow::ParseError, "invalid render tag: no 'as' found"

			# StringScanner#pre_match is broken, so we have to do the equivalent
			# ourselves.
			offset = scanner.pos - scanner.matched.length - 1
			@methodchain = scanner.string[ start..offset ]

		# No methodchain
		else
			scanner.scan_until( AS ) or
				raise Arrow::ParseError, "invalid render tag: no 'as' found"
			@methodchain = ''
			self.log.debug "No methodchain parsed"
		end

		# Parse the target identifier
		@target = parser.scan_for_identifier( state ) or
			raise Arrow::ParseError, "missing or malformed target identifier"
		self.log.debug "Parsed target identifier: %p" % [@target]

		# Skip over the ' in ' bit
		scanner.skip( WHITESPACE )
		scanner.skip( IN ) or
			raise Arrow::ParseError, "invalid render tag: no 'in'"
		scanner.skip( WHITESPACE )

		# Parse the filename of the subtemplate to load
		filename = parser.scan_for_pathname( state ) or
			raise Arrow::ParseError, "No filename found for 'render'"
		filename.untaint
		self.log.debug "Parsed subtemplate filename: %p" % [filename]

		# Load and parse the subtemplate
		@subtemplate = self.loadSubtemplate( filename, parser, state )
		self.log.debug "Subtemplate set to: %p" % [@subtemplate]

		return true
	end


	### Render the directive's value via the specified attribute in the delegate
	### template.
	def render_contents( template, scope )
		data = super

		@subtemplate.send( "#{@target}=", data )
		self.log.debug "Rendering %p" % [@subtemplate]
		return @subtemplate.render( nil, scope, template )
	end


	### Load and parse a subtemplate from the given filename using the specified
	### parser.
	def loadSubtemplate( filename, parser, state )
		nodes = nil
		load_path = state.template._load_path
		path = Arrow::Template.find_file( filename, load_path )
		subtemplate = nil
		
		# If the template has already been loaded, just reuse the nodelist
		state.data[:loadCache] ||= {}
		if state.data[:loadCache].include?( path )
			self.log.debug "Re-using cache template instance for %p" % path
			subtemplate = state.data[:loadCache][ path ]
			
		else
			# Load the content of the file and untaint it
			self.log.debug "Loading %p for the first time" % path
			content = File.read( path )
			content.untaint

			# Load a blank template object, cache it, then parse the content
			# into nodes and install the resulting syntax tree in the
			# template. The template object is created before parsing so that
			# recursive renders work.
			initialData = state.data.dup
			subtemplate = initialData[:loadCache][ path ] = Arrow::Template.new()
			nodes = parser.parse( content, state.template, initialData )
			subtemplate.install_syntax_tree( nodes )
		end

		return subtemplate
	rescue Arrow::TemplateError, ::IOError => err
		msg = "#{err.class.name}: Render with #{filename}: #{err.message}"
		@nodes = [ Arrow::Template::CommentNode.new(msg) ]
	end


end # class Arrow::Template::RenderDirective


