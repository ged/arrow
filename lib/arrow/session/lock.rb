#!/usr/bin/ruby
# 
# This file contains the Arrow::Session::Lock class, which is the abstract
# superclass for session lock object classes. Locks are objects which fulfill
# the locking interface of Arrow::Session, providing a way of serializing access
# to session data.
# 
# == Rcsid
# 
# $Id: lock.rb,v 1.1 2003/10/13 04:20:13 deveiant Exp $
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

require 'uri'

require 'arrow/object'
require 'arrow/exceptions'
require 'arrow/mixins'

module Arrow
class Session

	### The abstract base class for session lock manager objects.
	class Lock < Arrow::Object
		include Arrow::Factory

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: lock.rb,v 1.1 2003/10/13 04:20:13 deveiant Exp $

		# Lock status flags
		UNLOCKED	= 0b00
		READ		= 0b01
		WRITE		= 0b10


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Returns the Array of directories to search for derivatives; part of
		### the Arrow::Factory interface.
		def self::derivativeDirs
			[ 'arrow/session', 'arrow/session/lock' ]
		end


		### Create a new Arrow::Session::Lock object for the given +id+ of the
		### type specified by +uri+.
		def self::create( uri, id )
			uri = Arrow::Session::parseUri( uri ) if
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
		def readLock( blocking=true )
			return true if self.readLocked?
			self.acquireReadLock( blocking ) or return false
			@status |= READ
			return true
		end


		### Acquire a write (exclusive) lock. If +blocking+ is false, will
		### return +false+ if the lock was not able to be acquired.
		def writeLock( blocking=true )
			return true if self.writeLocked?
			self.acquireWriteLock( blocking ) or return false
			@status |= WRITE
			return true
		end

		
		### Execute the given block after obtaining a read lock, and give up the
		### lock when the block returns. If +blocking+ is false, will raise an
		### Errno::EAGAIN error without calling the block if the lock cannot be
		### immediately established.
		def withReadLock( blocking=true )
			begin
				self.readLock( blocking ) or raise Errno::EAGAIN
				yield
			ensure
				self.releaseReadLock
			end
		end


		### Execute the given block after obtaining a write lock, and give up
		### the lock when the block returns. If +blocking+ is false, will raise
		### an Errno::EAGAIN error without calling the block if the lock cannot
		### be immediately established.
		def withWriteLock( blocking=true )
			begin
				self.writeLock( blocking ) or raise Errno::EAGAIN
				yield
			ensure
				self.releaseWriteLock
			end
		end


		### Returns +true+ if the lock object currently holds either a read or
		### write lock.
		def locked?
			(@status & (READ|WRITE)).nonzero?
		end


		### Returns +true+ if the lock object has acquired a read lock.
		def readLocked?
			(@status & READ).nonzero?
		end


		### Returns +true+ if the lock object has acquired a write lock.
		def writeLocked?
			(@status & WRITE).nonzero?
		end


		### Give up a read (shared) lock. Raises an exception if no read lock
		### has been acquired.
		def readUnlock
			raise LockingError, "No read lock to release" unless
				self.readLocked?
			self.releaseReadLock
			@status &= ( @status ^ READ )
		end


		### Release a write (exclusive) lock. Raises an exception if no write
		### lock has been acquired.
		def writeUnlock
			raise LockingError, "No write lock to release" unless
				self.writeLocked?
			self.releaseWriteLock
			@status &= ( @status ^ WRITE )
		end

		
		### Release any locks acquired by this lock object.
		def releaseAllLocks
			return false unless self.locked?
			self.writeUnlock if self.writeLocked?
			self.readUnlock if self.readLocked?
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
		def acquireReadLock( blocking )
			raise UnimplementedError,
				"%s does not provide an implementation of #acquireReadLock." %
				self.class.name
		end


		### Interface method for concrete derivatives: acquire a write lock
		### through whatever mechanism is being implemented. If +blocking+ is
		### +true+, the method should only return if the lock was successfully
		### acquired. If +blocking+ is +false+, this method should attempt the
		### lock and return +false+ immediately if the lock was not able to the
		### acquired. Concrete implementations should *not* call +super+ for
		### this method.
		def acquireWriteLock( blocking )
			raise UnimplementedError,
				"%s does not provide an implementation of #acquireWriteLock." %
				self.class.name
		end


		### Interface method for concrete derivatives: release a read lock
		### through whatever mechanism is being implemented. Concrete
		### implementations should *not* call +super+ for this method.
		def releaseReadLock
			raise UnimplementedError,
				"%s does not provide an implementation of #releaseReadLock." %
				self.class.name
		end


		### Interface method for concrete derivatives: release a write lock
		### through whatever mechanism is being implemented. Concrete
		### implementations should *not* call +super+ for this method.
		def releaseWriteLock
			raise UnimplementedError,
				"%s does not provide an implementation of #releaseWriteLock." %
				self.class.name
		end



	end # class Lock

end # class Session
end # module Arrow


