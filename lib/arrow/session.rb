#!/usr/bin/ruby
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
require 'hashslice'
require 'pluginfactory'

require 'arrow/object'
require 'arrow/exceptions'
require 'arrow/mixins'
require 'arrow/logger'

module Arrow

	### This provides a container for maintaining state across multiple transactions..
	class Session < Arrow::Object
		include PluginFactory, Enumerable

		require 'arrow/session/store'
		require 'arrow/session/lock'
		require 'arrow/session/id'


		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		
		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		@config = {}
		class << self
			attr_reader :config
		end

		### Parse the given string into a URI object, appending the path part if
		### it doesn't exist.
		def self::parseUri( str )
			return str if str.is_a?( URI )
			str += ":." if /^\w+$/ =~ str
			URI::parse( str )
		end


		### Configure the session class's factory with the given Arrow::Config
		### object.
		def self::configure( config )
			@config = config.session.dup
			Arrow::Logger[self].debug "Done. Session config is: %p" % @config
		end


		### Create a new session for the specified +request+.
		def self::create( txn, configHash={} )
			request = txn.request
		
			# Merge the incoming config with the factory's
			sconfig = @config.merge( configHash )

			# Fetch the id from the request, either from the session cookie or
			# as a parameter if the cookie doesn't exist.
			if request.cookies.key?( sconfig.idName )
				idstring = request.cookies[ sconfig.idName ].value
			else
				idstring = request.param( sconfig.idName )
			end

			# Create a new id and backing store object
			Arrow::Logger[self].debug "Creating a session id: %p" % sconfig.idType
			idobj = Arrow::Session::Id::create( sconfig.idType, request, idstring )
			Arrow::Logger[self].debug "Creating a session store: %p" % sconfig.storeType
			store = Arrow::Session::Store::create( sconfig.storeType, idobj )

			# If the configuration says to use the recommended locker, ask the
			# backing store for a lock object.
			lockuri = Arrow::Session::parseUri( sconfig.lockType )
			if lockuri.scheme == 'recommended'
				Arrow::Logger[self].debug "Creating recommended lock"
				lock = store.createRecommendedLock( idobj ) or
					raise SessionError, "No recommended locker for %s" %
						store.class.name
			else
				Arrow::Logger[self].debug "Creating a session lock: %p" % lockuri
				lock = Arrow::Session::Lock::create( lockuri, idobj )
			end

			# Set the session cookie
			if defined?( Apache )
				scookie = Apache::Cookie::new request,
					:name => sconfig.idName,
					:value => idobj.to_s,
					:expires => sconfig.expires,
					:path => txn.appRoot

				Arrow::Logger[self].debug "Created cookie: %p" % scookie
			else
				scookie = nil
			end

			# Create the new session
			return new( idobj, lock, store, txn, scookie )
		end


		#########
		protected
		#########

		### Create delegators that readlock the session store before accessing
		### it.
		def self::def_delegated_readers( *syms )
			syms.each {|sym|
				define_method( sym ) {|*args|
					@lock.readLock
					@store.send( sym, *args )
				}
			}
		end


		### Create delegators that writelock the session store before accessing
		### it.
		def self::def_delegated_writers( *syms )
			syms.each {|sym|
				define_method( sym ) {|*args|
					@lock.writeLock
					@store.send( sym, *args )
				}
			}
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

			self.log.debug "Initializing session with id: %p, lock: %p, store: %p"

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
			@lock.withWriteLock {
				@store.remove
			}
			@lock.releaseAllLocks
			@cookie.expires = Time::at(0)
		end


		### Clear all data from the session object.
		def clear
			@lock.writeLock
			@store.clear
			@store[ :_session_id ] = @id.to_s
		end


		### Enumerable iterface: iterate over the session's key/value pairs,
		### calling the given block once for each pair.
		def each( &block )
			raise LocalJumpError, "no block given" unless block
			@lock.readLock
			@store.each( &block )
		end


		### Save the session to fixed storage and set the session cookie in the
		### creating transaction's outgoing headers.
		def save
			begin
				@store.save
				@cookie.bake
			ensure
				@lock.releaseAllLocks
			end
		end


		### Delegate the common hash methods to the session store, which
		### re-delegates them to its data.
		def_delegated_readers :[], :default, :default=, :each, :each_key,
			:each_pair, :each_value, :empty?, :fetch, :has_key?, :has_value?,
			:include?, :index, :invert, :keys, :length, :member?, :merge,
			:rehash, :reject, :select, :size, :sort, :to_a, :value?, :values

		alias_method :key?, :has_key?
		alias_method :value?, :has_value?

		def_delegated_writers :[]=, :delete, :clear, :merge!, :replace,
			:delete_if, :reject!

	end # class Session

end # module Arrow


