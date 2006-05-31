#!/usr/bin/ruby
# 
# This file contains the Arrow::Config class, instances of which use used to
# load and save configuration values for an Arrow application.
# 
# == Description
# The configuration values are as follows:
#
# [<b>startMonitor</b>]
#	Start the monitoring subsystem. Defaults to +false+.
# [<b>noSuchAppletHandler</b>]
#   The URI of the applet which should handle requests for applets that don't
#   exist. A value of '(builtin)' (the default) will cause a builtin handler to
#   be invoked.
# [<b>errorHandler</b>]
#	The URI of the applet which should handle untrapped exceptions raised
#	from other applets. A value of '(builtin)' (the default) will cause a
#	builtin handler to be invoked.
# [<b>logLevels</b>]
#	The verbosity level of logging for various classes. Each key in this hash
#	should be the name of an Arrow class or 'global'. Possible values are the
#	same as the Apache logging levels: debug, info, notice, warn, error, crit,
#	alert, and emerg.
# [<b>applets</b>]
#	Applet configuration values:
#	[<b>path</b>]
#	  An Arrow::Path object or colon-delimited list of directories to search for
#	  applet files. Defaults to: "./applets:/www/applets".
#   [<b>pattern</b>]
#	  A glob pattern that will be used to search for applets to
#	  load. Default to '*.rb'.
#   [<b>pollInterval</b>]
#	  The number of seconds between checks of the applet path for
#	  new/updated/deleted applet files. Defaults to 5.
# [<b>templates</b>]
#	Template configuration values:
#   [<b>loader</b>]
#	  The name of a class or module to use to load templates for use in the
#	  appserver. Defaults to 'Arrow::Template'.
#	[<b>path</b>]
#	  An Arrow::Path object or colon-delimited list of directories to search for
#	  templates. Defaults to "templates:/www/templates".
#	[<b>cache</b>]
#	  Flag that determines whether or not templates are cached in an LRU cache
#	  in the TemplateFactory or loaded anew everytime. Default to +true+
#	  (templates are cached).
#	[<b>cacheConfig</b>]
#	  Configuration for the template cache. If template caching is turned off,
#	  this section is ignored.
#		<b>maxNum</b>::		The maximum number of templates to cache. Default to 20.
#		<b>maxSize</b>::	The maximum estimated size of all cached objects. When
#							the cache exceeds this size in bytes, the
#							least-recently used one/s will be dropped until the
#							cache's total size is less than this value.
#		<b>maxObjSize</b>:: The maximum size of the cache, in bytes. If an
#							object exceeeds this number of bytes in estimated
#							size, it will not be cached.
#		<b>expiration</b>:: The maximum lifetime of an object in the cache, in
#							seconds. Objects which were cached more than this
#							number of seconds before retrieval will be dropped.
# [<b>session</b>]
#   Session configuration values:
#	[<b>idType</b>]
#	  A URI which represents the id class to use and its configuration. See the
#	  documentation for Arrow::Session::Id and its derivatives for the form of
#	  the URI. 'md5:.' is the default.
#	[<b>lockType</b>]
#	  A URI which specifies what locking class to use and its configuration. If
#	  this is the string +'recommended'+, the lock object will be created by
#	  calling the #create_recommended_lock method of the store. Defaults to
#	  'recommended'. See Arrow::Session::Lock and its derivatives for the format
#	  of the URI.
#	[<b>storeType</b>]
#	  A URI which specifies what backing store class to use for storing the
#	  session data between requests and its configuration. Default to
#	  'file:/tmp'; see the documentation for Arrow::Session::Store and its
#	  derivatives for the form of the URI.
#	[<b>idName</b>]
#	  The name of the session cookie and/or the session id parameter that will
#	  be inserted in rewritten URLs. Defaults to 'arrow-session'.
#	[<b>rewriteUrls</b>]
#	  If set to +true+, any self-referential URLs in the appserver's output will
#	  be rewritten to include the session id as a parameter. Defaults to +true+.
#	[<b>expires</b>]
#	  Set the expiration time of the session cookie. Defaults to "+48h"; see
#	  documentation for Apache::Cookie#expires for the format of the string.
# 
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
# Please see the file docs/COPYRIGHT for licensing details.
#

require 'pp'
require 'uri'
require 'pluginfactory'
require 'forwardable'

require 'arrow'
require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/utils'
require 'arrow/object'

require 'stringio'
require 'forwardable'
require 'uri'

### Instances of this class contain configuration values for for an Arrow
### web application.
class Arrow::Config < Arrow::Object
	extend Forwardable

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Output a debugging message to STDERR
	def self.debugMsg( *msgs )
		$stderr.puts msgs.join
	end


	# Define the layout and defaults for the underlying structs
	Defaults = {
		:startMonitor			=> false,

		:logLevels				=> { :global => 'notice' },

		:applets => {
			:path			=> Arrow::Path.new( "applets:/www/applets" ),
			:pattern		=> '*.rb',
			:pollInterval	=> 5,
			:layout			=> {},
			:config			=> {},
			:missingApplet	=> '/missing',
			:errorApplet	=> '/error',
		},

		:templates => {
			:loader			=> 'Arrow::Template',
			:path			=> Arrow::Path.new( "templates:/www/templates" ),
			:cache			=> true,
			:cacheConfig	=> {
				:maxNum			=> 20,
				:maxSize		=> (1<<17) * 20,
				:maxObjSize		=> (1<<17),
				:expiration		=> 36
			},
		},

		:session => {
			:idType			=> 'md5:.',
			:lockType		=> 'recommended',
			:storeType		=> 'file:/tmp',
			:idName			=> 'arrow-session',
			:rewriteUrls	=> true,
			:expires		=> "+48h",
		},
	}
	Defaults.freeze



	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### The default config file loader to use
	@defaultLoader = 'yaml'
	@loaders = {}
	class << self
		attr_accessor :defaultLoader, :loaders
	end


	### Get the loader by the given name, creating a new one if one is not
	### already instantiated.
	def self.getLoader( name=nil )
		name ||= self.defaultLoader
		self.loaders[name] ||= Arrow::Config::Loader.create( name )
	end


	### Read and return an Arrow::Config object from the given file or
	### configuration source using the specified +loader+.
	def self.load( source, loaderObj=nil )
		loaderObj = self.getLoader( loaderObj ) unless
			loaderObj.is_a?( Arrow::Config::Loader )
		confighash = loaderObj.load( source )

		obj = new( untaintValues(confighash) )
		obj.loader = loaderObj
		obj.name = source

		return obj
	end


	### Return a copy of the specified +hash+ with all of its values
	### untainted.
	def self.untaintValues( hash )
		newhash = {}
		hash.each {|key,val|
			case val
			when Hash
				newhash[ key ] = untaintValues( hash[key] )

			when NilClass, TrueClass, FalseClass, Numeric, Symbol
				newhash[ key ] = val

			when Arrow::Path
				# Arrow::Logger[ self ].debug "Untainting %p" % val
				val.untaint
				newhash[ key ] = val

			when Array
				# Arrow::Logger[ self ].debug "Untainting array %p" % val
				newval = val.collect {|v| v.dup.untaint}
				newhash[ key ] = newval

			else
				# Arrow::Logger[ self ].debug "Untainting %p" % val
				newval = val.dup
				newval.untaint
				newhash[ key ] = newval
			end
		}
		return newhash
	end


	### Return a duplicate of the given +hash+ with its identifier-like keys
	### transformed into symbols from whatever they were before.
	def self.internifyKeys( hash )
		newhash = {}
		hash.each {|key,val|
			if val.is_a?( Hash )
				newhash[ key.to_s.intern ] = internifyKeys( val )
			else
				newhash[ key.to_s.intern ] = val
			end
		}

		return newhash
	end


	### Return a version of the given +hash+ with its keys transformed
	### into Strings from whatever they were before.
	def self.stringifyKeys( hash )
		newhash = {}
		hash.each {|key,val|
			if val.is_a?( Hash )
				newhash[ key.to_s ] = stringifyKeys( val )
			else
				newhash[ key.to_s ] = val
			end
		}

		return newhash
	end



	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Config object. Values passed in via the
	### +confighash+ will be used instead of the defaults.
	def initialize( confighash={} )
		ihash = self.class.internifyKeys( confighash )
		# self.log.debug "Ihash is %p" % ihash
		mergedhash = Defaults.merge( ihash, &Arrow::HashMergeFunction )
		# self.log.debug "Merged hash is %p" % mergedhash
		@struct = ConfigStruct.new( mergedhash )
		@createTime = Time.now
		@name = nil
		@loader = self.class.getLoader

		super()
	end


	######
	public
	######

	# Define delegators to the inner data structure
	def_delegators :@struct, :to_h, :member?, :members, :merge, :merge!, :each,
		:[], :[]=

	# The underlying config data structure
	attr_reader :struct

	# The time the configuration was loaded
	attr_accessor :createTime

	# The loader that will be used to save this config
	attr_reader :loader

	# The name of the associated record stored on permanent storage for this
	# configuration.
	attr_accessor :name


	### Change the configuration object's loader. The +newLoader+ argument
	### can be either an Arrow::Config::Loader object or the name of one
	### suitable for passing to Arrow::Config::Loader.create.
	def loader=( newLoader )
		if newLoader.is_a?( Arrow::Config::Loader )
			@loader = newLoader
		else
			@loader = self.class.getLoader( newLoader )
		end
	end


	### Write the configuration object using the specified name and any
	### additional +args+.
	def write( name=@name, *args )
		raise ArgumentError,
			"No name associated with this config." unless name
		lobj = self.loader
		strHash = self.class.stringifyKeys( @struct.to_h )
		self.loader.save( strHash, name, *args )
	end


	### Returns +true+ for methods which can be autoloaded
	def respond_to?( sym )
		return true if @struct.member?( sym.to_s.sub(/(=|\?)$/, '').intern )
		super
	end


	### Returns +true+ if the configuration has changed since it was last
	### loaded, either by setting one of its members or changing the file
	### from which it was loaded.
	def changed?
		if @struct.modified?
			self.log.debug "Struct was modified"
			return true
		end
		return false unless self.name
		if self.loader.isNewer?( self.name, self.createTime )
			self.log.debug "Config source (%s) has been updated since %s" %
				[ self.name, self.createTime ]
			return true
		end
	end


	### Reload the configuration from the original source if it has
	### changed. Returns +true+ if it was reloaded and +false+ otherwise.
	def reload
		return false unless @loader && @name
		confighash = @loader.load( @name )
		ihash = self.class.internifyKeys( self.class.untaintValues(confighash) )
		mergedhash = Defaults.merge( ihash, &Arrow::HashMergeFunction )
		@struct = ConfigStruct.new( mergedhash )
	end


	#########
	protected
	#########

	### Handle calls to struct-members
	def method_missing( sym, *args )
		key = sym.to_s.sub( /(=|\?)$/, '' ).intern
		return super unless @struct.member?( key )

		self.log.debug( "Autoloading #{key} accessors." )

		self.class.class_eval %{
			def #{key}; @struct.#{key}; end
			def #{key}=(*args); @struct.#{key} = *args; end
			def #{key}?; @struct.#{key}?; end
		}

		@struct.__send__( sym, *args )
	end


	#############################################################
	###	I N T E R I O R   C L A S S E S
	#############################################################

	### Hash-wrapper that allows struct-like accessor calls on nested
	### hashes.
	class ConfigStruct < Arrow::Object
		include Enumerable
		extend Forwardable

		# Mask most of Kernel's methods away so they don't collide with
		# config values.
		Kernel.methods(false).each {|meth|
			next unless method_defined?( meth )
			next if /^(?:__|dup|object_id|inspect|class|raise|method_missing)/.match( meth )
			undef_method( meth )
		}

		# Forward some methods to the internal hash
		def_delegators :@hash, :keys, :key?, :values, :value?, :[], :[]=, :length,
		    :empty?, :clear


		### Create a new ConfigStruct from the given +hash+.
		def initialize( hash )
			@hash = hash.dup
			@dirty = false
		end


		######
		public
		######

		# Modification flag. Set to +true+ to indicate the contents of the
		# Struct have changed since it was created.
		attr_writer :modified


		### Returns +true+ if the ConfigStruct or any of its sub-structs
		### have changed since it was created.
		def modified?
			@dirty || @hash.values.find do |obj|
				obj.is_a?( ConfigStruct ) && obj.modified?
			end
		end


		### Return the receiver's values as a (possibly multi-dimensional)
		### Hash with String keys.
		def to_hash
			rhash = {}
			@hash.each {|k,v|
				case v
				when ConfigStruct
					rhash[k] = v.to_h
				when NilClass, FalseClass, TrueClass, Numeric
					# No-op (can't dup)
					rhash[k] = v
				when Symbol
					rhash[k] = v.to_s
				else
					rhash[k] = v.dup
				end
			}
			return rhash
		end
        alias_method :to_h, :to_hash
        

		### Return +true+ if the receiver responds to the given
		### method. Overridden to grok autoloaded methods.
		def respond_to?( sym, priv=false )
			key = sym.to_s.sub( /(=|\?)$/, '' ).intern
			return true if @hash.key?( key )
			super
		end


		### Returns an Array of Symbols, on for each of the struct's members.
		def members
			@hash.keys
		end


		### Returns +true+ if the given +name+ is the name of a member of
		### the receiver.
		def member?( name )
			return @hash.key?( name.to_s.intern )
		end


		### Call into the given block for each member of the receiver.
		def each( &block ) # :yield: member, value
			@hash.each( &block )
		end
		alias_method :each_section, :each


		### Merge the specified +other+ object with this config struct. The
		### +other+ object can be either a Hash, another ConfigStruct, or an
		### Arrow::Config.
		def merge!( other )
			case other
			when Hash
				@hash = self.to_h.merge( other,
					&Arrow::HashMergeFunction )

			when ConfigStruct
				@hash = self.to_h.merge( other.to_h,
					&Arrow::HashMergeFunction )

			when Arrow::Config
				@hash = self.to_h.merge( other.struct.to_h,
					&Arrow::HashMergeFunction )

			else
				raise TypeError,
					"Don't know how to merge with a %p" % other.class
			end

			# :TODO: Actually check to see if anything has changed?
			@dirty = true

			return self
		end


		### Return a new ConfigStruct which is the result of merging the
		### receiver with the given +other+ object (a Hash or another
		### ConfigStruct).
		def merge( other )
			self.dup.merge!( other )
		end


		#########
		protected
		#########

		### Handle calls to key-methods
		def method_missing( sym, *args )
			key = sym.to_s.sub( /(=|\?)$/, '' ).intern
			super unless @hash.key?( key )

			self.class.class_eval {
				define_method( key ) {
					if @hash[ key ].is_a?( Hash )
						@hash[ key ] = ConfigStruct.new( @hash[key] )
					end

					@hash[ key ]
				}
				define_method( "#{key}?" ) {@hash[key] ? true : false}
				define_method( "#{key}=" ) {|val|
					@dirty = @hash[key] != val
					@hash[key] = val
				}
			}

			self.__send__( sym, *args )
		end
	end # class ConfigStruct


	### Abstract base class (and Factory) for configuration loader
	### delegates. Create specific instances with the
	### Arrow::Config::Loader.create method.
	class Loader < Arrow::Object
		include PluginFactory

		#########################################################
		###	C L A S S   M E T H O D S
		#########################################################

		### Returns a list of directories to search for deriviatives.
		def self.derivativeDirs
			["arrow/config-loaders"]
		end


		#########################################################
		###	I N S T A N C E   M E T H O D S
		#########################################################

		######
		public
		######

		### Load configuration values from the storage medium associated
		### with the given +name+ (e.g., filename, rowid, etc.) and return
		### them in the form of a (possibly multi-dimensional) Hash.
		def load( name )
			raise NotImplementedError,
				"required method 'load' not implemented in '#{self.class.name}'"
		end


		### Save configuration values from the given +confighash+ to the
		### storage medium associated with the given +name+ (e.g., filename,
		### rowid, etc.) and return them.
		def save( confighash, name )
			raise NotImplementedError,
				"required method 'save' not implemented in '#{self.class.name}'"
		end


		### Returns +true+ if the configuration values in the storage medium
		### associated with the given +name+ has changed since the given
		### +time+.
		def isNewer?( name, time )
			raise NotImplementedError,
				"required method 'isNewer?' not implemented in '#{self.class.name}'"
		end

	end # class Loader

end # class Arrow::Config


### If run directly, write a default config file to the current directory
if __FILE__ == $0
	filename = ARGV.shift || "default.cfg" 
	loader = ARGV.shift || Arrow::Config.defaultLoader

	$stderr.puts "Dumping default configuration to '%s' using the '%s' loader" %
		[ filename, loader ]

	conf = Arrow::Config.new
	conf.loader = loader
	conf.write( filename )
end
