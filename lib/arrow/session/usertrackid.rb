#!/usr/bin/ruby
# 
# This file contains the Arrow::Session::UsertrackId class, a derivative of
# Arrow::Session::Id. This class creates session id objects which uses Apache's
# builtin mod_usertrack for the session key.
# 
# == Rcsid
# 
# $Id: usertrackid.rb,v 1.2 2003/11/09 22:27:47 deveiant Exp $
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
require 'arrow/session/id'

module Arrow
class Session

	### A session id object which uses Apache's builtin mod_usertrack id..
	class UserTrackId < Arrow::Session::Id

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.2 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: usertrackid.rb,v 1.2 2003/11/09 22:27:47 deveiant Exp $

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

	end # class UsertrackId

end # class Session
end # module Arrow


