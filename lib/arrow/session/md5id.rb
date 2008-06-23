#!/usr/bin/env ruby
# 
# This file contains the Arrow::Session::MD5Id class, a derivative of
# Arrow::Session::Id. Instances of this class are session IDs created by
# MD5-hashing some semi-random data with
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

require 'digest/md5'

require 'arrow/session/id'

### MD5 Session IDs class.
class Arrow::Session::MD5Id < Arrow::Session::Id

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Generate a new id
	def self::generate( uri, request )
		seed = [
			Time.new.to_s,
			Object.new.inspect,
			rand(),
			Process.pid,
		].join
		return Digest::MD5.hexdigest( Digest::MD5.hexdigest(seed) )
	end

	### Returns the validated id if the given id is in the expected form for
	### this type, or +nil+ if it is not.
	def self::validate( uri, idstr )
		rval = idstr[/^([a-f0-9]{32})$/]
		rval.untaint
		return rval
	end

end # class Arrow::Session::MD5Id
