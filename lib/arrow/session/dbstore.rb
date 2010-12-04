#!/usr/bin/env ruby

require 'sequel'

require 'arrow/exceptions'
require 'arrow/session/store'

# The Arrow::Session::DbStore class, a derivative of Arrow::Session::Store.
# Instances of this class store a session object in a database.
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
class Arrow::Session::DbStore < Arrow::Session::Store


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new Arrow::Session::DbStore object.
	def initialize( uri, idobj )
		
		db = Sequel.connect( uri )
		dataset = db[]
		@id = idobj
		super
	end


	######
	public
	######

	# The database handle
	attr_reader :db

	# The session ID this store was created for
	attr_reader :id


	### Insert the specified +data+ hash into whatever permanent storage the
	### Store object is acting as an interface to.
	def insert
		super {|data|
			self.log.debug "Inserting data into session table for session %s" % [ self.id ]
			self.
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


end # class Arrow::Session::DbStore


