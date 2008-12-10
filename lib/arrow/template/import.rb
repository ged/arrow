#!/usr/bin/env ruby

require 'arrow/template/nodes'
require 'arrow/template/parser'

# The Arrow::Template::ImportDirective class, a derivative of
# Arrow::Template::Directive. This is the class which defines the behaviour of
# the 'import' template directive.
#
# === Syntax
#
#   <?import foo?>
#   <?import foo as superfoo?>
#	<?import foo, bar?>
#	<?import foo as superfoo, bar, baz as bazish?>
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#
class Arrow::Template::ImportDirective < Arrow::Template::Directive # :nodoc:
	include Arrow::Template::Parser::Patterns

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$
	
	# Various patterns
	SIMPLEIMPORT = CAPTURE[ IDENTIFIER ]
	ALIASIMPORT = CAPTURE[ IDENTIFIER ] + /\s+as\s+/i + CAPTURE[ IDENTIFIER ]


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################
	
	### Disallow formats
	def self::allows_format?; false; end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################
	
	### Create a new ImportDirective object.
	def initialize( type, parser, state )
		@imports = {}
		super
	end


	######
	public
	######

	# An Array of Regexp objects which match the names of attributes to be
	# imported.
	attr_reader :patterns


	### Add the imported attributes when this node is rendered.
	def render( template, scope )
		imports = []

		if (( st = template._enclosing_template ))
			@imports.each do |source,dest|
				imports << "%s as %s (%p)" %
					[ source, dest, st._attributes[source] ]
				template._attributes[dest] = st._attributes[source]
			end
		end

		if template._config[:debuggingComments]
			return template.render_comment( "Importing: " + imports.join(", ") )
		else
			return ''
		end
	end


	#########
	protected
	#########

	### Parse the contents of the directive.
	def parse_directive_contents( parser, state )
		super

		state.scanner.skip( WHITESPACE )
		#self.log.debug "Scanning for tag middle at: '%20s'" % state.scanner.rest

		body = state.scanner.scan( state.tag_middle ) or return nil
		#self.log.debug "Found body = %p" % body

		body.strip.split( /\s*,\s*/ ).each do |import|
			#self.log.debug "Parsing import: %p" % import
			case import
			when ALIASIMPORT
				@imports[ $1 ] = $2
				#self.log.debug "Alias import: %s => %s" % 
				#	[ $1, $2 ]

			when SIMPLEIMPORT
				@imports[ $1 ] = $1
				#self.log.debug "Simple import: %s" % $1

			else
				raise Arrow::ParseError, "Failed to parse body: %p" % body
			end
		end

		return true
	end

end # class Arrow::Template::ImportDirective
