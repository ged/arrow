#!/usr/bin/ruby
# 
# This file contains the Arrow::Session::MD5Id class, a derivative of
# Arrow::Session::Id. Instances of this class are session IDs created by
# MD5-hashing some semi-random data with
# 
# == Rcsid
# 
# $Id: md5id.rb,v 1.3 2003/11/09 22:26:38 deveiant Exp $
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

require 'digest/md5'

require 'arrow/session/id'

module Arrow
class Session

	### MD5 Session IDs class.
	class MD5Id < Arrow::Session::Id

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.3 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: md5id.rb,v 1.3 2003/11/09 22:26:38 deveiant Exp $


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Generate a new id
		def self::generate( uri, request )
			seed = [
				Time::new.to_s,
				Object::new.inspect,
				rand(),
				Process::pid,
			].join
			return Digest::MD5::hexdigest( Digest::MD5::hexdigest(seed) )
		end

		### Returns the validated id if the given id is in the expected form for
		### this type, or +nil+ if it is not.
		def self::validate( uri, idstr )
			rval = idstr[/^([a-f0-9]{32})$/]
			rval.untaint
			return rval
		end

	end # class MD5Id

end # class Session
end # module Arrow


