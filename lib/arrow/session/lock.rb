#!/usr/bin/env ruby

require 'uri'
require 'pluginfactory'

require 'arrow/object'
require 'arrow/exceptions'
require 'arrow/mixins'
require 'arrow/session'


# The Arrow::Session::Lock class, which is the abstract
# superclass for session lock object classes. Locks are objects which fulfill
# the locking interface of Arrow::Session, providing a way of serializing
# access to session data.
# 
# To derive your own lock manager classes from this class, you'll need to 
# follow the following interface:
#
# === Derivative Interface ===
# 
# Locking is achieved via four methods: #acquire_read_lock, #acquire_write_lock,
# #release_read_lock, and #release_write_lock. These methods provide the
# #concurrency for sessions shared between multiple servers. You will probably
# #also want to provide your own initializer to capture the session's ID.
# 
# #initialize( uri=string, id=Arrow::Session::Id )
#
# #acquire_read_lock::
#   Acquire a shared lock on the session data.
#
# #acquire_write_lock::
#   Acquire an exclusive lock on the session data.
# 
# #release_read_lock
#   Release a shared lock on the session data.
#
# #release_write_lock::
#   Release an exclusive lock on the session data.
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Session::Lock < Arrow::Object
	include PluginFactory

	# Lock status flags
	UNLOCKED	= 0b00
	READ		= 0b01
	WRITE		= 0b10


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Returns the Array of directories to search for derivatives; part of
	### the PluginFactory interface.
	def self::derivativeDirs
		[ 'arrow/session', 'arrow/session/lock' ]
	end


	### Create a new Arrow::Session::Lock object for the given +id+ of the
	### type specified by +uri+.
	def self::create( uri, id )
		uri = Arrow::Session.parse_uri( uri ) if
			uri.is_a?( String )
		super( uri.scheme.dup, uri, id )
	end



	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Session::Lock object.
	def initialize( uri, id )
		super()
		@status = UNLOCKED
	end


	######
	public
	######

	### Acquire a read (shared) lock. If +blocking+ is false, will return
	### +false+ if the lock was not able to be acquired.
	def read_lock( blocking=true )
		return true if self.read_locked?
		self.log.debug "Acquiring read lock"
		self.acquire_read_lock( blocking ) or return false
		@status |= READ
		self.log.debug "Got read lock"
		return true
	end


	### Acquire a write (exclusive) lock. If +blocking+ is false, will
	### return +false+ if the lock was not able to be acquired.
	def write_lock( blocking=true )
		return true if self.write_locked?
		self.log.debug "Acquiring write lock"
		self.acquire_write_lock( blocking ) or return false
		@status |= WRITE
		self.log.debug "Got write lock"
		return true
	end


	### Execute the given block after obtaining a read lock, and give up the
	### lock when the block returns. If +blocking+ is false, will raise an
	### Errno::EAGAIN error without calling the block if the lock cannot be
	### immediately established.
	def with_read_lock( blocking=true )
		begin
			self.read_lock( blocking ) or raise Errno::EAGAIN
			yield
		ensure
			self.release_read_lock
		end
	end


	### Execute the given block after obtaining a write lock, and give up
	### the lock when the block returns. If +blocking+ is false, will raise
	### an Errno::EAGAIN error without calling the block if the lock cannot
	### be immediately established.
	def with_write_lock( blocking=true )
		begin
			self.write_lock( blocking ) or raise Errno::EAGAIN
			yield
		ensure
			self.release_write_lock
		end
	end


	### Returns +true+ if the lock object currently holds either a read or
	### write lock.
	def locked?
		(@status & (READ|WRITE)).nonzero?
	end


	### Returns +true+ if the lock object has acquired a read lock.
	def read_locked?
		(@status & READ).nonzero?
	end


	### Returns +true+ if the lock object has acquired a write lock.
	def write_locked?
		(@status & WRITE).nonzero?
	end


	### Give up a read (shared) lock. Raises an exception if no read lock
	### has been acquired.
	def read_unlock
		raise Arrow::LockingError, "No read lock to release" unless
			self.read_locked?
		self.log.debug "Releasing read lock"
		self.release_read_lock
		@status &= ( @status ^ READ )
	end


	### Release a write (exclusive) lock. Raises an exception if no write
	### lock has been acquired.
	def write_unlock
		raise Arrow::LockingError, "No write lock to release" unless
			self.write_locked?
		self.log.debug "Releasing write lock"
		self.release_write_lock
		@status &= ( @status ^ WRITE )
	end


	### Release any locks acquired by this lock object.
	def release_all_locks
		return false unless self.locked?
		self.write_unlock if self.write_locked?
		self.read_unlock if self.read_locked?
	end


	### Indicate to the lock that the caller will no longer be using it, and
	### it may free any resources it had been using.
	def finish
		self.release_all_locks
	end


	#########
	protected
	#########

	### Interface method for concrete derivatives: acquire a read lock
	### through whatever mechanism is being implemented. If +blocking+ is
	### +true+, the method should only return if the lock was successfully
	### acquired. If +blocking+ is +false+, this method should attempt the
	### lock and return +false+ immediately if the lock was not able to the
	### acquired. Concrete implementations should *not* call +super+ for
	### this method.
	def acquire_read_lock( blocking )
		raise UnimplementedError,
			"%s does not provide an implementation of #acquire_read_lock." %
			self.class.name
	end


	### Interface method for concrete derivatives: acquire a write lock
	### through whatever mechanism is being implemented. If +blocking+ is
	### +true+, the method should only return if the lock was successfully
	### acquired. If +blocking+ is +false+, this method should attempt the
	### lock and return +false+ immediately if the lock was not able to the
	### acquired. Concrete implementations should *not* call +super+ for
	### this method.
	def acquire_write_lock( blocking )
		raise UnimplementedError,
			"%s does not provide an implementation of #acquire_write_lock." %
			self.class.name
	end


	### Interface method for concrete derivatives: release a read lock
	### through whatever mechanism is being implemented. Concrete
	### implementations should *not* call +super+ for this method.
	def release_read_lock
		raise UnimplementedError,
			"%s does not provide an implementation of #release_read_lock." %
			self.class.name
	end


	### Interface method for concrete derivatives: release a write lock
	### through whatever mechanism is being implemented. Concrete
	### implementations should *not* call +super+ for this method.
	def release_write_lock
		raise UnimplementedError,
			"%s does not provide an implementation of #release_write_lock." %
			self.class.name
	end

end # class Arrow::Session::Lock


