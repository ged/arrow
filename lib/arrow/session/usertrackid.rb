#!/usr/bin/ruby
# 
# This file contains the Arrow::Session::UsertrackId class, a derivative of
# Arrow::Session::Id. This class creates session id objects which uses Apache's
# builtin mod_usertrack for the session key.
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
require 'arrow/session/id'

module Arrow
class Session

	### A session id object which uses Apache's builtin mod_usertrack id..
	class UserTrackId < Arrow::Session::Id

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

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


