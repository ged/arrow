#!/usr/bin/ruby
# 
# This file contains the Arrow::Session::FileLock class, a derivative of
# Arrow::Session::Lock. Instances of this class provide file-based locking for
# Arrow sessions using the flock(2) system call.  It (obviously) won't work on
# platforms which don't support flock(2).
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

require 'ftools'

require 'arrow/session/lock'

module Arrow
class Session

	### File-based lock manager for Arrow sessions using the flock(2) system
	### call.
	class FileLock < Arrow::Session::Lock

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

		# The path to the default lockdir
		DefaultLockDir = '/tmp'

		# The format string that will be used for the name of the lock file. The
		# first '%s' will be replaced with a sanitized version of the session
		# id.
		LockfileFormat = "arrow-session-%s.lock"

		# The mode to open the lockfile in
		FileMode = File::APPEND|File::CREAT|File::TRUNC


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Clean the specified +directory+ of lock files older than +threshold+
		### seconds.
		def self::clean( directory=DefaultLockDir, threshold=3600 )
			pat = File::join( directory, LockfileFormat.gsub(/%s/, '*') )
			threshold = Time::now - threshold
			Dir[ pat ].each {|file|
				if File::mtime( file ) < threshold
					Arrow::Logger[self].info \
						"Removing stale lockfile '%s'" % file
					begin
						fh = File::open( file, FileMode )
						fh.flock( File::LOCK_EX|File::LOCK_NB )
						File::delete( file )
						fh.flock( File::LOCK_UN )
						fh.close
					rescue => err
						Arrow::Logger[self].warning \
							"Could not clean up '%s': %s" %
							[ file, err.message ]
						next
					end
				end
			}
		end



		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new Arrow::Session::FileLock object.
		def initialize( uri, id )
			@lockDir = uri.path || DefaultLockDir
			super

			File::mkpath( @lockDir )
			@filename = File::join( @lockDir, LockfileFormat % id.to_s.gsub(/\W/, '_') ).untaint
			@lockfile = nil
		end


		######
		public
		######

		# The path to the directory where session lockfiles are kept.
		attr_accessor :lockDir


		#########
		protected
		#########

		### Get the File object for the lockfile belonging to this lock,
		### creating it if necessary.
		def lockfile
			@lockfile ||= File::open( @filename, FileMode )
		end


		### Close the lockfile and destroy the File object belonging to this
		### lock.
		def closeLockfile
			if @lockfile
				path = @lockfile.path
				@lockfile.close
				@lockfile = nil
				File::delete( path.untaint )
			end
		end


		### Acquire a read (shared) lock on the lockfile.
		def acquireReadLock( blocking )
			flags = File::LOCK_SH
			flags |= File::LOCK_NB if !blocking

			self.lockfile.flock( flags )
		end


		### Acquire a write (exclusive) lock on the lockfile.
		def acquireWriteLock( blocking )
			flags = File::LOCK_EX
			flags |= File::LOCK_NB if !blocking

			self.lockfile.flock( flags )
		end


		### Release a previously-acquired read lock.
		def releaseReadLock
			if !self.writeLocked?
				self.lockfile.flock( File::LOCK_UN )
				self.closeLockfile
			end
		end


		### Release a previously-acquired write lock.
		def releaseWriteLock
			if self.readLocked?
				self.lockfile.flock( File::LOCK_SH )
			else
				self.lockfile.flock( File::LOCK_UN )
				self.closeLockfile
			end
		end

	end # class FileLock

end # class Session
end # module Arrow


