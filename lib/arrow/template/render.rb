#!/usr/bin/ruby
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
class Arrow::Template::RenderDirective < Arrow::Template::AttributeDirective
	include Arrow::Template::Parser::Patterns

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Parse tokens
	AS = /\s+as\s+/i
	IN = /in/i
	

	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Disallow formats
	def self::allowsFormat; false; end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new RenderDirective object.
	def initialize( type, parser, state )
		@target = nil
		@subtemplate = nil
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
	def parseDirectiveContents( parser, state )
		
		@name = parser.scanForIdentifier( state, true ) or
			raise ParseError, "missing or malformed identifier"
			
		# If there's an infix operator, the rest of the tag up to the 'as' is
		# the methodchain. Else there isn't one.
		if state.scanner.skip( INFIX )
			state.scanner.scan_until( AS ) or
				raise Arrow::ParseError, "invalid render tag: no 'as' found"
			@methodchain = state.scanner.pre_match || ''
		else
			state.scanner.scan_until( AS ) or
				raise Arrow::ParseError, "invalid render tag: no 'as' found"
			@methodchain = ''
		end

		# Parse the target identifier
		@target = parser.scanForIdentifier( state ) or
			raise Arrow::ParseError, "missing or malformed target identifier"

		state.scanner.skip( WHITESPACE )
		state.scanner.skip( IN ) or
			raise Arrow::ParseError, "invalid render tag: no 'in'"
		state.scanner.skip( WHITESPACE )

		# Parse the filename of the subtemplate to load
		filename = parser.scanForPathname( state ) or
			raise Arrow::ParseError, "No filename found for 'render'"
		filename.untaint

		# Load it
		@subtemplate = Arrow::Template::load( filename )
		self.log.debug "Subtemplate is: %p" % [ @subtemplate ]
			
		return true
	end


	### Render the directive's value via the specified attribute in the delegate
	### template.
	def renderContents( template, scope )
		data = super

		@subtemplate.send( "#{@target}=", data )
		return @subtemplate.render( nil, scope, template )
	end

end # class Arrow::Template::RenderDirective


