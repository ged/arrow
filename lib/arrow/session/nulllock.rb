#!/usr/bin/env ruby
# 
# This file contains the Arrow::Session::NullLock class, a derivative of
# Arrow::Session::Lock. This is a null lock, in that it does not lock.
# This is to be used with an ActiveRecord session store that uses
# Optomistic Concurrency Control.
# 
# == Subversion ID
# 
# $Id$
# 
# == Authors
# 
# * Jeremiah Jordan <phaedrus@FaerieMUD.org>
# 
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the BASE directory for licensing details.
#

require 'arrow/session/lock'

### This lock type uses the 'posixlock' library..
class Arrow::Session::NullLock < Arrow::Session::Lock

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	def initialize( uri, id )
		super
	end

	def acquire_read_lock(blocking)
		true
	end

	def acquire_write_lock(blocking)
		true
	end

	def release_read_lock
		true
	end

	def release_write_lock
		true
	end

end
