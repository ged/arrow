#!/usr/bin/ruby
# 
# This file contains the Arrow::Session::Store class, a derivative of
# Arrow::Object. Instances of concrete deriviatives of this class provide
# serialization and semi-permanent storage of session data for Arrow::Session
# objects.
# 
# == Rcsid
# 
# $Id: store.rb,v 1.8 2004/01/25 05:06:22 deveiant Exp $
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

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/session/lock'

module Arrow
class Session

	### Serialization and semi-permanent session-data storage class.
	class Store < Arrow::Object
		include Arrow::Factory
		extend Forwardable

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.8 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: store.rb,v 1.8 2004/01/25 05:06:22 deveiant Exp $

		# The URI of the lock class recommended for use with this Store.
		RecommendedLocker = URI::parse( 'file:.' )

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
		### the Arrow::Factory interface.
		def self::derivativeDirs
			[ 'arrow/session', 'arrow/session/store' ]
		end


		### Overridden factory method: handle a URI object or a name
		def self::create( uri, idobj )
			uri = Arrow::Session::parseUri( uri ) if uri.is_a?( String )
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
		def delete_if( &block ) # :yields: key, value
			rval = @data.reject!( &block )
			return @data
		ensure
			@modified = true if rval
		end


		### Deletes every key-value pair from the session data for which the
		### +block+ evaluates to true.
		def reject!( &block ) # :yields: key, value
			rval = @data.reject!( &block )
			return rval
		ensure
			@modified = true if rval
		end


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
			yield( self.serializedData )
			@new = @modified = false
		end


		### Update the current data hash stored in permanent storage with the
		### values contained in the store's data. Concrete implementations
		### should provide an overriding implementation of this method that
		### calls #super with a block which will be called with the serialized
		### data that should be stored.
		def update
			self.log.debug "Updating session data for key %s" % @id
			yield( self.serializedData )
			@modified = false
		end


		### Retrieve the data hash stored in permanent storage associated with
		### the id the object was created with. Concrete implementations
		### should provide an overriding implementation of this method that calls
		### #super with a block that returns the serialized data to be restored.
		def retrieve
			self.log.debug "Retrieving session data for key %s" % @id
			self.serializedData = yield
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
		def createRecommendedLock( idobj )
			self.log.debug "Searching for recommended lock for %s" %
				self.class.name
			adviceClass = self.class.ancestors.find {|klass|
				klass.const_defined?( :RecommendedLocker )
			} or raise SessionError, "No recommended locker for %p" %
				self.class.ancestors
			uri = adviceClass.const_get( :RecommendedLocker ) or
				raise SessionError, "Could not fetch RecommendedLocker constant"

			self.log.debug "Creating recommeded lock %s" % uri
			uri = Arrow::Session::parseUri( uri ) if
				uri.is_a?( String )

			lock = Arrow::Session::Lock::create( uri, idobj )
			self.log.debug "Created recommended lock object: %p" % lock

			return lock
		end


		#########
		protected
		#########

		### Returns the data in the session store as a serialized object.
		def serializedData
			data = stripHash( @data )			
			return Marshal::dump( data )
		end


		### Sets the session's data by deserializing the object
		### contained in the given +string+.
		def serializedData=( string )
			if string.empty?
				self.log.error "No session data: retaining default hash"
			else
				@data = Marshal::restore( string )
			end
		end

		

		#######
		private
		#######
		
		### Return a copy of the given +hash+ with all non-serializable
		### objects stipped out of it.
		def stripHash( hash, cloned=true )
			newhash = cloned ? hash.dup : hash
			newhash.default = nil if newhash.default_proc
			newhash.each_key {|key|
				case newhash[ key ]
				when Hash
					newHash[ key ] = stripHash( newhash[key], false )
					
				when Proc, Method, UnboundMethod, IO
					self.log.warning "Stripping unserializable object from session " \
						"hash: %p" % newhash[ key ]
					newHash[ key ] = "[Can't serialize a %s]" % newhash[ key ].class
				end
			}
			
			return newhash
		end
		


	end # class Store

end # class Session
end # module Arrow


