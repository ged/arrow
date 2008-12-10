#!/usr/bin/env ruby

require 'posixlock'
require 'ftools'

require 'arrow/session/lock'

# The Arrow::Session::PosixLock class, a derivative of
# Arrow::Session::Lock. This lock type uses the 'posixlock' library
# (http://raa.ruby-lang.org/project/posixlock/).
# 
# == Subversion ID
# 
# $Id$
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
class Arrow::Session::PosixLock < Arrow::Session::Lock

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# The path to the default lockdir
	DefaultLockDir = '/tmp'

	# The format string that will be used for the name of the lock file. The
	# first '%s' will be replaced with a sanitized version of the session
	# id.
	LockfileFormat = "arrow-session-%s.plock"

	# The mode to open the lockfile in
	FileMode = File::CREAT|File::RDWR


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Clean the specified +directory+ of lock files older than +threshold+
	### seconds.
	def self::clean( directory=DefaultLockDir, threshold=3600 )
		pat = File.join( directory, LockfileFormat.gsub(/%s/, '*') )
		threshold = Time.now - threshold
		Dir[ pat ].each do |file|
			if File.mtime( file ) < threshold
				Arrow::Logger[self].info \
				"Removing stale lockfile '%s'" % file
				begin
					fh = File.open( file, FileMode )
					fh.posixlock( File::LOCK_EX|File::LOCK_NB )
					File.delete( file )
					fh.posixlock( File::LOCK_UN )
					fh.close
				rescue => err
					Arrow::Logger[self].warning \
					"Could not clean up '%s': %s" %
						[ file, err.message ]
					next
				end
			end
		end
	end



	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Session::FileLock object.
	def initialize( uri, id )
		@lockDir = uri.path || DefaultLockDir
		super

		File.mkpath( @lockDir )
		@filename = File.join( @lockDir, LockfileFormat % id.to_s.gsub(/\W/, '_') ).untaint
		self.log.debug "Filename is: #@filename"
		@lockfile = nil
	end


	######
	public
	######

	# The path to the directory where session lockfiles are kept.
	attr_accessor :lockDir


	### Indicate to the lock that the caller will no longer be using it, and it
	### may free any resources it had been using.
	def finish
		super
		self.close_lock_file
	end



	#########
	protected
	#########

	### Get the File object for the lockfile belonging to this lock,
	### creating it if necessary.
	def lockfile
		@lockfile ||= File.open( @filename, FileMode )
	end


	### Close the lockfile and destroy the File object belonging to this
	### lock.
	def close_lock_file
		if @lockfile
			path = @lockfile.path
			@lockfile.close
			@lockfile = nil
			if File.exist?( path.untaint )
				File.delete( path.untaint )
			end
		end
	end


	### Acquire a read (shared) lock on the lockfile.
	def acquire_read_lock( blocking )
		flags = File::LOCK_SH
		flags |= File::LOCK_NB if !blocking

		self.lockfile.posixlock( flags )
	end


	### Acquire a write (exclusive) lock on the lockfile.
	def acquire_write_lock( blocking )
		flags = File::LOCK_EX
		flags |= File::LOCK_NB if !blocking

		self.lockfile.posixlock( flags )
	end


	### Release a previously-acquired read lock.
	def release_read_lock
		if !self.write_locked?
			self.lockfile.posixlock( File::LOCK_UN )
			self.close_lock_file
		end
	end


	### Release a previously-acquired write lock.
	def release_write_lock
		if self.read_locked?
			self.lockfile.posixlock( File::LOCK_SH )
		else
			self.lockfile.posixlock( File::LOCK_UN )
			self.close_lock_file
		end
	end

end # module Arrow::Session::PosixLock



