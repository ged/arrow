#!/usr/bin/env ruby
# 
# This file contains the Arrow::Session class, a derivative of
# Arrow::Object. This provides a container for maintaining state across multiple transactions.
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

require 'uri'
require 'pluginfactory'

require 'arrow/object'
require 'arrow/exceptions'
require 'arrow/mixins'
require 'arrow/logger'
require 'arrow/config'


### This provides a container for maintaining state across multiple transactions.
class Arrow::Session < Arrow::Object
	include PluginFactory,
		Enumerable,
		Arrow::Configurable

	config_key :session

	require 'arrow/session/store'
	require 'arrow/session/lock'
	require 'arrow/session/id'


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	
	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	@config = Arrow::Config.new
	class << self
		attr_reader :config
	end

	### Parse the given string into a URI object, appending the path part if
	### it doesn't exist.
	def self::parse_uri( str )
		return str if str.is_a?( URI::Generic )
		str += ":." if /^\w+$/ =~ str
		URI.parse( str )
	end


	### Configure the session class's factory with the given Arrow::Config
	### object.
	def self::configure( config )
		@config = config.dup
		Arrow::Logger[self].debug "Done. Session config is: %p" % @config
	end


	### Create a new session for the specified +request+.
	def self::create( txn, configHash={} )
		# Merge the incoming config with the factory's
		sconfig = @config.merge( configHash )
		Arrow::Logger[self].debug "Merged config is: %p" % sconfig

		# Create a new id and backing store object
        idobj = self.create_id( sconfig, txn )
        store = self.create_store( sconfig, idobj )
        lock = self.create_lock( sconfig, store, idobj )

		# Create the session cookie
        scookie = self.create_session_cookie( txn, sconfig, idobj, store, lock )

		return new( idobj, lock, store, txn, scookie )
	end


    ### Set the session cookie if we're really running under Apache.
    def self::create_session_cookie( txn, config, id, store, lock )
		scookie = Arrow::Cookie.new(
				config.idName,
				id.to_s,
				:expires => config.expires,
				:path => '/'
			)

		Arrow::Logger[self].debug "Created cookie: %p" % scookie.to_s
        return scookie
    end


    ### Create an Arrow::Session::Id object for the given +txn+, with the 
    ### particulars dictated by the specified +config+.
    def self::create_id( config, txn )
		cookie_name = config.idName
	
        # Fetch the id from the request, either from the session cookie or
		# as a parameter if the cookie doesn't exist.
		if txn.request_cookies.include?( cookie_name )
			Arrow::Logger[self].debug "Found an existing session cookie (%s)" %
				[ cookie_name ]
			idstring = txn.request_cookies[ cookie_name ].value
		else
			Arrow::Logger[self].debug \
				"No existing session cookie (%s); looking for one in a request parameter" %
				[ cookie_name]
			idstring = txn.param( cookie_name )
		end

		Arrow::Logger[self].debug "Creating a session id object: %p" % config.idType
		return Arrow::Session::Id.create( config.idType, txn.request, idstring )
	end
	

	### Create an Arrow::Session::Store object with the given +id+. The type 
	### and configuration of the store will be dictated by the specified 
	### +config+ object.
    def self::create_store( config,  id )
        Arrow::Logger[self].debug "Creating a session store: %p" % config.storeType
		return Arrow::Session::Store.create( config.storeType, id )
    end
    

	### Create an Arrow::Session::Lock object for the specified +store+ and +id+.
	def self::create_lock( config, store, id )
	    
		lockuri = Arrow::Session.parse_uri( config.lockType )
        lock = nil

		# If the configuration says to use the recommended locker, ask the
		# backing store for a lock object.
		if lockuri.scheme == 'recommended'
			Arrow::Logger[self].debug "Creating recommended lock"
			lock = store.create_recommended_lock( id ) or
				raise Arrow::SessionError, "No recommended locker for %s" %
					store.class.name
		else
			Arrow::Logger[self].debug "Creating a session lock: %p" % lockuri
			lock = Arrow::Session::Lock.create( lockuri, id )
		end

	   return lock
	end
	
	
	### Return the configured name of the session cookie.
	def self::session_cookie_name
		return @config.idName
	end
	
	

	#########
	protected
	#########

	### Create delegators that readlock the session store before accessing
	### it.
	def self::def_delegated_readers( *syms )
		syms.each do |sym|
			define_method( sym ) do |*args|
				@lock.read_lock
				@store.send( sym, *args )
			end
		end
	end


	### Create delegators that writelock the session store before accessing
	### it.
	def self::def_delegated_writers( *syms )
		syms.each do |sym|
			define_method( sym ) do |*args|
				@lock.write_lock
				@store.send( sym, *args )
			end
		end
	end



	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Session object for the given +idobj+ (an
	### Arrow::Session::Id object), using the given +lock+ (an
	### Arrow::Session::Locker object) for serializing access. 
	def initialize( idobj, lock, store, txn, cookie=nil )
		raise ArgumentError, "No id object" unless idobj
		raise ArgumentError, "No lock object" unless lock
		raise ArgumentError, "No store object" unless store

		self.log.debug "Initializing session with id: %p, lock: %p, store: %p" %
			[ idobj, lock, store ]

		@id = idobj
		@lock = lock
		@store = store
		@txn = txn
		@cookie = cookie

		@store[ :_session_id ] = id.to_s
	end


	######
	public
	######

	# The session's unique identifier, an Apache::Session::Id object.
	attr_reader :id

	# The session's backing store; an Apache::Session::Store object.
	attr_reader :store

	# The session's lock object; an Apache::Session::Lock.
	attr_reader :lock

	# The Apache::Cookie object used to manipulate the session cookie.
	attr_reader :cookie


	### Delete the session
	def remove
		@lock.with_write_lock do
			@store.remove
		end
		@lock.release_all_locks
		@cookie.expires = Time.at(0)
	end


	### Clear all data from the session object.
	def clear
		@lock.with_write_lock do
    		@store.clear
    		@store[ :_session_id ] = @id.to_s
		end
	end


	### Enumerable iterface: iterate over the session's key/value pairs,
	### calling the given block once for each pair.
	def each( &block )
		raise LocalJumpError, "no block given" unless block
		@lock.read_lock
		@store.each( &block )
	end


	### Save the session to fixed storage and set the session cookie in the
	### creating transaction's outgoing headers.
	def save
		begin
			self.log.debug "Saving session data"
			@store.save
			self.log.debug "Writing session cookie (%p)" % [ @cookie ]
			@txn.cookies[ self.class.session_cookie_name ] = @cookie
		ensure
			self.log.debug "Releasing all locks"
			@lock.release_all_locks
		end
	end


	### Tell the session that it will not be used again in the current
	### session.
	def finish
		@lock.release_all_locks
	end


	### Delegate the common hash methods to the session store, which
	### re-delegates them to its data.
	def_delegated_readers :[], :default, :default=, :each, :each_key,
		:each_pair, :each_value, :empty?, :fetch, :has_key?, :has_value?,
		:include?, :index, :invert, :key?, :keys, :length, :member?, :merge,
		:rehash, :reject, :select, :size, :sort, :to_a, :value?, :values

	def_delegated_writers :[]=, :delete, :clear, :merge!, :replace,
		:delete_if, :reject!

end # class Arrow::Session


