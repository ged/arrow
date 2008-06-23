#!/usr/bin/env ruby
# 
# This file contains a collection of exception classes for the Arrow web
# application framework.
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
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the BASE directory for licensing details.
#

module Arrow

	### Base exception class
	class Exception < StandardError
		Message = "Arrow framework error"

		def initialize( message=nil )
			message ||= self.class.const_get( "Message" )
			super( message )
		end
	end

	### Define an exception class with the specified <tt>name</tt> (a Symbol)
	### with the specified <tt>message</tt>. The new exception class will
	### inherit from the specified <tt>superclass</tt>, if specified, or
	### <tt>StandardError</tt> if not specified.
	def Arrow.def_exception( name, message, superclass=Arrow::Exception )
		name = name.id2name if name.kind_of?( Fixnum )
		eClass = Class.new( superclass )
		eClass.module_eval %Q{
			def initialize( *args )
				if ! args.empty?
					msg = args.collect {|a| a.to_s}.join
					super( msg )
				else
					super( message )
				end					
			end
		}

		const_set( name, eClass )
	end


	# System exceptions
	def_exception :ConfigError,				"Configuration error"
	def_exception :LockingError,			"Locking error"
	def_exception :SessionError,			"Error in session"

	# Templating errors
	def_exception :TemplateError,			"Error in templating system"
	def_exception :ParseError,				"Error while parsing",
		TemplateError
	def_exception :ScopeError,				"Error in rendering scope",
		TemplateError

	# Signal exceptions
	def_exception :Reload,					"Configuration out of date"
	def_exception :Shutdown,				"Server shutdown"

	# Applet errors
	def_exception :AppletError,				"Applet error"
	def_exception :AppletChainError,		"Malformed applet chain"

	# Datasource errors
	def_exception :TypeError,				"Data type incompatible"
	def_exception :LoadError,				"Loading failed"

end # module Arrow

