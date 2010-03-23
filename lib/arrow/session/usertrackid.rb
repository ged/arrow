#!/usr/bin/env ruby

require 'arrow/exceptions'
require 'arrow/session/id'

# The Arrow::Session::UsertrackId class, a derivative of Arrow::Session::Id. 
# This class creates session id objects which uses Apache's builtin 
# mod_usertrack for the session key.
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Session::UserTrackId < Arrow::Session::Id



	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Returns an untainted copy of the specified +idstring+ if it is in
	### the expected form for this type of id.
	def self::validate( uri, idstring )
		return nil if idstring.nil?
		rval = idstring[/^[\w.]+\.\d+$/] or return nil?
		rval.untaint
		return rval
	end


	### Generate a new id string for the given request
	def self::generate( uri, request )
		if uri.path
			cookieName = uri.path.sub( %r{^/}, '' )
		else
			cookieName = 'Apache'
		end

		unless request.cookies.key?( cookieName )
			raise SessionError, "No cookie named '%s' was found. Make sure "\
				"mod_usertrack is enabled and configured correctly" %
				cookieName
		end

		return validate( uri, request.cookies[cookieName].value )
	end

end # class Arrow::Session::UsertrackId

