#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::ImportDirective class, a derivative of
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
# == Rcsid
# 
# $Id: import.rb,v 1.1 2003/12/10 18:50:24 deveiant Exp $
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

module Arrow
class Template

	### The class which defines the behaviour of the 'import' template
	### directive.
	class ImportDirective < Arrow::Template::Directive
		include Arrow::Template::Parser::Patterns


		# CVS version string
		Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

		# CVS Id string
		Rcsid = %q$Id: import.rb,v 1.1 2003/12/10 18:50:24 deveiant Exp $

		# Various patterns
		SIMPLEIMPORT = CAPTURE[ IDENTIFIER ]
		ALIASIMPORT = CAPTURE[ IDENTIFIER ] + /\s+as\s+/i + CAPTURE[ IDENTIFIER ]


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################
		
		### Disallow formats
		def self::allowsFormat; false; end


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


		### Parse the contents of the directive.
		def parseDirectiveContents( parser, state )
			super

			state.scanner.skip( WHITESPACE )
			self.log.debug "Scanning for tag middle at: '%20s'" % state.scanner.rest

			body = state.scanner.scan( state.tagMiddle ) or return nil
			self.log.debug "Found body = %p" % body

			body.strip.split( /\s*,\s*/ ).each {|import|
				self.log.debug "Parsing import: %p" % import
				case import
				when ALIASIMPORT
					@imports[ $1 ] = $2
					self.log.debug "Alias import: %s => %s" % 
						[ $1, $2 ]

				when SIMPLEIMPORT
					@imports[ $1 ] = $1
					self.log.debug "Simple import: %s" % $1

				else
					raise ParseError, "Failed to parse body: %p" % body
				end
			}

			return true
		end


		### Add the imported attributes when this node is rendered.
		def render( template, scope )
			imports = []

			if (( st = template._superTemplate ))
				@imports.each {|source,dest|
					imports << "%s as %s (%p)" %
						[ source, dest, st._attributes[source] ]
					template._attributes[dest] = st._attributes[source]
				}
			end

			if template._config[:debuggingComments]
				return template.renderComment( "Importing: " + imports.join(", ") )
			else
				return ''
			end
		end

	end # class ImportDirective

end # class Template
end # module Arrow


