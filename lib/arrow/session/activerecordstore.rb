#!/usr/bin/env ruby
# 
# This file contains the Arrow::Session::ActiveRecordStore class, a derivative of
# Arrow::Session::Store. Instances of this class store a session object as a
# row via an ActiveRecord database abstraction.
# 
# == Config URI
#  session:
#    storeType: activerecord:Blog::Session
#    lockType: null
#
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Jeremiah Jordan <phaedrus@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'arrow/exceptions'
require 'arrow/session/store'

require 'active_record'
require 'yaml'


### ActiveRecord session store class.
class Arrow::Session::ActiveRecordStore < Arrow::Session::Store

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The name of the recommended locker to use with this session store type. Since
	# ActiveRecord does its own optimistic locking, just use the null locker.
	RecommendedLocker = 'null'
	
	
	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new ActiveRecordStore object, using the (ActiveRecord::Base 
	### subclass) class specified by the given +klass_uri+.
	def initialize( klass_uri, idobj )
		klass_string = klass_uri.opaque or
			raise Arrow::ConfigError, "Invalid session storeType URI %p" % [klass_uri]
		@klass = find_class( klass_string ) or
			raise Arrow::ConfigError, "No such class for session storeType %s" % [klass_uri]
		@instance = nil

		super
	end


	######
	public
	######

	# The ActiveRecord::Base (-like?) object which should be instantiated to store
	# the session data
	attr_reader :klass


	### Insert the specified +data+ hash into the database.
	def insert
		dbo = nil
		
		super {|data|
			dbo = self.db_object
			self.log.debug "Saving session to the database."
			dbo.session_data = data
			self.log.debug "Session db object is at version %d" % [dbo.lock_version]
			
			unless dbo.save
				raise Arrow::SessionError, 
					"Could not save session: %s" % [ dbo.errors.full_messages.join(', ') ]
			end
			self.log.debug "Session data saved."
		}
	rescue ActiveRecord::StaleObjectError => err
		otherdbo = @klass.find_by_session_id( @id.to_s )
		self.log.notice "Conflicting session updates:  %p" %
			[ otherdbo.attributes.diff(dbo.attributes) ]
		# :TODO: Handle merging sessions
		
	rescue ActiveRecord::ActiveRecordError => err
		# :TODO: Give up on the session after logging the error, but don't 
		# propagate the exception.
		self.log.error "Error inserting/saving session: %s at %s" %
			[err.message, err.backtrace.first]
	end
	alias_method :update, :insert


	### Fetch the session data hash from the session object in the database
	def retrieve
		self.log.debug "Retrieving session %s from the database" % [ @id.to_s ]
		super { self.db_object.session_data }
		self.log.debug "Retrieved session %s" % [ @id.to_s ]
	end


	### Remove the session data object from the database
	def remove
		self.log.debug "Removing session %s from the database" % [@id.to_s]
		super
		@klass.delete( @id.to_s )
		@instance = nil
	end



	#########
	protected
	#########

	### Let ActiveRecord do its own serialization
	def serialized_data # :nodoc:
		self.log.debug "Fetching serialized data (%p)" % [ @data ]
		@data
	end

	### Let ActiveRecord do its own deserialization
	def serialized_data=( data ) # :nodoc:
		data ||= {}
		self.log.debug "Setting serialized data to: %p" % [ data ]
		@data = data
	end


	#########
	protected
	#########

	### Look up or create the session data object in the database and return it.
	def db_object
		if @instance.nil?
			self.log.debug "Fetching session object from the database (id = %p)" %
				[ @id.to_s ]
			@instance = @klass.find_or_create_by_session_id( @id.to_s )
			@instance.session_data = {} if @instance.new_record?
		end
		
		return @instance
	end
	

	#######
	private
	#######

	### Given the name of a class, return the Class instance or nil if the class 
	### doesn't exist.
	def find_class( classname )
		classname.split(/::/).inject( Object ) {|mod,const| mod.const_get(const) }
	end

end
