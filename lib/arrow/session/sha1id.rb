#!/usr/bin/env ruby

require 'digest/sha1'

require 'arrow/session/id'

# The Arrow::Session::SHA1Id class, a derivative of
# Arrow::Session::Id. Instances of this class are session IDs created by
# SHA1-hashing some semi-random data.
# 
# == Synopsis
#
#   # In arrow.conf:
#	session:
#	  idType: sha1:.
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
class Arrow::Session::SHA1Id < Arrow::Session::Id

	# Default salt characters
	DEFAULT_SALT = 'sadblkw456jbhgsdfi7283hnehonaseegop26m'


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Generate a new id
	def self::generate( uri, request )
		salt = uri.opaque || DEFAULT_SALT
		seed = [
			salt,
			Time.new.to_s,
			Object.new.inspect,
			rand(),
			Process.pid,
		].join
		return Digest::SHA1.hexdigest( Digest::SHA1.hexdigest(seed) )
	end

	### Returns the validated id if the given id is in the expected form for
	### this type, or +nil+ if it is not.
	def self::validate( uri, idstr )
		rval = idstr[/^([a-f0-9]{40})$/]
		rval.untaint
		return rval
	end

end # class Arrow::Session::MD5Id
