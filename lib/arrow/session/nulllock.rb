#!/usr/bin/env ruby

require 'arrow/session/lock'

# The Arrow::Session::NullLock class, a derivative of
# Arrow::Session::Lock. This is a null lock, in that it does not lock.
# This is to be used with an ActiveRecord session store that uses
# Optomistic Concurrency Control.
# 
# == VCS Id
# 
# $Id$
# 
# == Authors
# 
# * Jeremiah Jordan <phaedrus@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Session::NullLock < Arrow::Session::Lock

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
