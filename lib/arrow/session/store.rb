#!/usr/bin/ruby
# 
# This file contains the Arrow::Session::Store class, a derivative of
# Arrow::Object. Instances of concrete deriviatives of this class provide
# serialization and semi-permanent storage of session data for Arrow::Session
# objects.
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

require 'forwardable'
require 'pluginfactory'

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/session'
require 'arrow/session/lock'

# Serialization and semi-permanent session-data storage class.
#
# === Derivative Interface ===
# 
# In order to create your own session store classes, you need to provide four 
# methods: #insert, #update, #retrieve, #remove. All but one of the methods
# provides serialization and marking records as dirty in the base class, so
# unless you want to manage these tasks yourself, you should +super()+ to the
# parent's implementation with a block. Examples are provided for each method.
#
# #insert::
#   Insert a new session into the backing store. Example:
#     def insert
#       super {|data| @io.print(data) }
#     end
# 
# #update::
#   Update an existing session's data in the backing store. Example:
#     def update
#       super {|data| @io.rewind; @io.truncate(0); @io.print(data) }
#     end
# 
# #retrieve::
#   Retrieve the serialized session data from the backing store. Example:
#     def retrieve
#       super { @io.rewind; @io.read }
#     end
# 
# #delete::
#   Delete the session from the backing store. Example:
#     def delete
#       super {|data| @io.close; File.delete(@session_file) }
#     end
# 
# === Optional Derivative Interface ===
# ==== Serialization ====
# 
# If you want to use something other than Marshal for object serialization,
# you can override the protected methods #serialized_data and #serialized_data=
# to provide your own serialization.
# 
# #serialized_data::
#   Serialize the data in the instance variable +@data+ and return it.
# #serialized_data=( serialized )::
#   Deserialize the given +serialized+ data and assign it to @data.
#
# Example (serializing to YAML instead of binary):
#     require 'yaml'
# 
#     def serialized_data
#       @data.to_yaml
#     end
#
#     def serialized_data=( data )
#       @data = YAML.load( data )
#     end
#
# ==== Lock Recommendation ====
# 
# If arrow is configured to use the 'recommended' session lock, your session
# store can recommend one it knows will work (e.g., if your session store is 
# a database, you can recommend a lock that uses database locking). The simple
# way to do that is to define a RecommendedLocker constant in your class which
# contains the URI of the locker you wish to use. If you need more control
# than the URI can provide, you can also override the #create_recommended_lock
# method, which should return an instance of the locker that should be used.
# 
# The method will be given the instantiated Arrow::Session::Lock object that
# identifies the session so that you can derive a filename, primary key, etc.
#
# Example:
#
#   def create_recommended_lock( idobj )
#     return DBITransactionLock.new( idobj.to_s )
#   end
#
# 
class Arrow::Session::Store < Arrow::Object
	include PluginFactory
	extend Forwardable

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The URI of the lock class recommended for use with this Store.
	RecommendedLocker = URI.parse( 'file:.' )

	# The methods which are delegate directly to the data hash.
	DelegatedMethods = [
		:[], :default, :default=, :each, :each_key, :each_pair, :each_value,
		:empty?, :fetch, :has_key?, :has_value?, :include?, :index, :invert,
		:keys, :length, :member?, :merge, :rehash, :reject, :select, :size,
		:sort, :to_a, :value?, :values
	]


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Returns the Array of directories to search for derivatives; part of
	### the PluginFactory interface.
	def self::derivativeDirs
		[ 'arrow/session', 'arrow/session/store' ]
	end


	### Overridden factory method: handle a URI object or a name
	def self::create( uri, idobj )
		uri = Arrow::Session.parse_uri( uri ) if uri.is_a?( String )
		super( uri.scheme.dup, uri, idobj )
	end



	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Session::Store object.
	def initialize( uri, idobj )
		@data		= {}
		@id			= idobj
		@new		= true
		@modified	= false

		unless idobj.new?
			self.retrieve
		end
		
		super()
	end


	######
	public
	######

	# Delegate some methods to the data hash directly.
	def_delegators :@data, *DelegatedMethods


	# The raw session data hash
	attr_reader :data


	### Set the +value+ for the specified +key+.
	def []=( key, value )
		@data[ key ] = value
		@modified = true
	end
	alias_method :store, :[]=


	### Deletes and returns a key-value pair from the receiver whose key is
	### equal to +key+. If the +key+ is not found, returns the default
	### value. If the optional code-block is given and the key is not found,
	### the block is called with the key, and the return value is used as
	### the result of the method.
	def delete( key, &block )
		rval = @data.delete( key, &block )
		return rval
	ensure
		@modified = true if rval != @data.default
	end


	### Clear all key/value pairs from the store for this session.
	def clear
		@data.clear
		@modified = true
	end


	### Adds the contents of the +other+ hash to the session data,
	### overwriting entries in the session data with values from the +other+
	### hash where there are duplicates. If a +block+ is given, it is called
	### for each duplicate key, and the return value is the value set in the
	### hash.
	def merge!( other, &block ) # :yields: key, sessionValue, otherValue
		@data.merge!( other, &block )
	ensure
		@modified = true
	end
	alias_method :update, :merge!


	### Replace the contents of the session hash with those of the given
	### +other+ hash.
	def replace( other )
		@data.replace( other )
	ensure
		@modified = true
	end


	### Deletes every key-value pair from the session data for which the
	### +block+ evaluates to true.
	def reject!( &block ) # :yields: key, value
		rval = @data.reject!( &block )
		return rval
	ensure
		@modified = true if rval
	end
	alias_method :delete_if, :reject!


	### Returns +true+ if the receiver's data is out of sync with the
	### data in the backing store.
	def modified?
		@modified
	end
	
	
	### Returns +true+ if the data in the receiver has not yet been saved to
	### the backing store, or if the entry in the backing store has been deleted
	### since it was last saved.
	def new?
		@new
	end


	### Save the session data to the backing store
	def save
		return false unless self.modified? || self.new?
		if self.new?
			self.insert
		else
			self.update
		end
	end		

	
	### Insert the current +data+ hash into whatever permanent storage the
	### Store object is acting as an interface to. Concrete implementations
	### should provide an overriding implementation of this method that
	### calls #super with a block which will be called with the serialized
	### data that should be stored.
	def insert
		self.log.debug "Inserting session data for key %s" % @id
		yield( self.serialized_data )
		@new = @modified = false
	end


	### Update the current data hash stored in permanent storage with the
	### values contained in the store's data. Concrete implementations
	### should provide an overriding implementation of this method that
	### calls #super with a block which will be called with the serialized
	### data that should be stored.
	def update
		self.log.debug "Updating session data for key %s" % @id
		yield( self.serialized_data )
		@modified = false
	end


	### Retrieve the data hash stored in permanent storage associated with
	### the id the object was created with. Concrete implementations
	### should provide an overriding implementation of this method that calls
	### #super with a block that returns the serialized data to be restored.
	def retrieve
		self.log.debug "Retrieving session data for key %s" % @id
		self.serialized_data = yield
		@new = @modified = false
	end


	### Permanently remove the data hash associated with the id used in the
	### receiver's creation from permanent storage.
	def remove
		self.log.debug "Removing session data for key %s" % @id
		@new = true
	end


	### Returns an instance of the recommended lock object for the receiving
	### store. If no recommended locking strategy is known, this method
	### raises a SessionError.
	def create_recommended_lock( idobj )
		self.log.debug "Searching for recommended lock for %s" %
			self.class.name

		# Traverse the class hierarchy to find a class which defines a
		# RecommendedLocker constant
		adviceClass = self.class.ancestors.find {|klass|
			klass.const_defined?( :RecommendedLocker )
		} or raise SessionError, "No recommended locker for %p" %
			self.class.ancestors

		uri = adviceClass.const_get( :RecommendedLocker ) or
			raise SessionError, "Could not fetch RecommendedLocker constant"

		self.log.debug "Creating recommeded lock %s" % uri
		uri = Arrow::Session.parse_uri( uri ) if
			uri.is_a?( String )

		lock = Arrow::Session::Lock.create( uri, idobj )
		self.log.debug "Created recommended lock object: %p" % lock

		return lock
	end


	#########
	protected
	#########

	### Returns the data in the session store as a serialized object.
	def serialized_data
		data = strip_hash( @data )			
		return Marshal.dump( data )
	end


	### Sets the session's data by deserializing the object
	### contained in the given +string+.
	def serialized_data=( string )
		if string.empty?
			self.log.error "No session data: retaining default hash"
		else
			@data = Marshal.restore( string )
		end
	end

	

	#######
	private
	#######
	
	### Return a copy of the given +hash+ with all non-serializable
	### objects stipped out of it.
	def strip_hash( hash, cloned=true )
		newhash = cloned ? hash.dup : hash
		newhash.default = nil if newhash.default_proc
		newhash.each_key {|key|
			case newhash[ key ]
			when Hash
				newHash[ key ] = strip_hash( newhash[key], false )
				
			when Proc, Method, UnboundMethod, IO
				self.log.warning "Stripping unserializable object from session " \
					"hash: %p" % newhash[ key ]
				newHash[ key ] = "[Can't serialize a %s]" % newhash[ key ].class
			end
		}
		
		return newhash
	end
	


end # class Arrow::Session::Store
