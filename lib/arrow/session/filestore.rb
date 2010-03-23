#!/usr/bin/env ruby

require 'arrow/exceptions'
require 'arrow/session/store'

# The Arrow::Session::FileStore class, a derivative of Arrow::Session::Store. 
# Instances of this class store a session object as a marshalled hash on disk.
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Session::FileStore < Arrow::Session::Store

	# The default flags to use when opening the backing store file
	DefaultIoFlags = File::RDWR|File::CREAT

	

	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new Arrow::Session::FileStore object.
	def initialize( uri, idobj )
		path = (uri.path || uri.opaque).dup
		path.untaint

		@dir = File.expand_path( path )
		@io = nil

		super
	end


	######
	public
	######

	# The fully-qualified directory in which session files will be written.
	attr_reader :dir


	### Return the fully-qualified path to the session file for this
	### store.
	def session_file
		return File.join( @dir, @id.to_s )
	end


	### Close the file after saving to make sure it's synched.
	def save
		super
		@io = nil
	end


	### Get the output filehandle for the session backing store
	### file. Open it with the specified +ioflags+ if it's not
	### already open.
	def open( ioflags=DefaultIoFlags )
		if @io.nil? || @io.closed?
			file = self.session_file
			self.log.debug "Opening session file %s" % file
			@io = File.open( file, File::RDWR|File::CREAT )
			@io.sync = true
		end

		return @io
	end


	### Close the output filehandle if it is opened.
	def close
		@io.close unless @io.nil? || @io.closed?
	end


	### Insert the specified +data+ hash into whatever permanent storage the
	### Store object is acting as an interface to.
	def insert
		super {|data|
			self.log.debug "Inserting data into session file"
			self.open( DefaultIoFlags|File::EXCL ).print( data )
		}
	end


	### Update the current data hash stored in permanent storage with the
	### values contained in +data+.
	def update
		super {|data|
			self.log.debug "Updating data in session file"
			ofh = self.open
			ofh.seek( 0, File::SEEK_SET )
			ofh.print( data )
		}
	end


	### Retrieve the data hash stored in permanent storage associated with
	### the id the object was created with.
	def retrieve
		super {
			self.log.debug "Reading data in session file"
			ofh = self.open( File::RDWR )
			ofh.seek( 0, File::SEEK_SET )
			ofh.read
		}
	end


	### Permanently remove the data hash associated with the id used in the
	### receiver's creation from permanent storage.
	def remove
		super
		self.close
		file = self.session_file
		if File.exists?( file )
			File.delete( file )
		else
			raise Arrow::SessionError,
				"Session file #{file} does not exist in the data store"
		end
	end


end # class Arrow::Session::FileStore


