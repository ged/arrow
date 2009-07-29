#!/usr/bin/env ruby

require 'rbconfig'
require 'forwardable'
require 'pathname'

require 'arrow'
require 'arrow/monkeypatches'
require 'arrow/constants'
require 'arrow/mixins'
require 'arrow/exceptions'

# The Arrow::Path class, which represents a collection of paths to
# search for various resources. Instances of this class are used to
# search for templates, applets, and other resources loaded by the
# server from a configured list of directories.
# 
# == Synopsis
# 
#    require 'arrow/path'
#    
#    # Constructed from a String with PATH_SEPARATOR characters:
#    template_path = Arrow::Path.new( ".:/www/templates:/usr/local/www/templates" )
#    
#    # ...or from an Array of Strings
#    template_path = Arrow::Path.new([ '.', '/www/templates', '/usr/local/www/templates' ])
#    
#    # Return only those paths that exist, are directories, are readable
#    # by the current user, and are not world-writable. This will use a
#    # cached value if it has been built within
#    # Arrow::Path::DEFAULT_CACHE_LIFESPAN seconds of the last fetch.
#    paths = template_path.valid_dirs
#    
#    # Fetch without caching
#    template_path.find_valid_dirs
#
#    # ...or turn caching off and fetch
#    template_path.cache_lifespan = 0
#    paths = template_path.valid_dirs
#    
# == Subversion Id
#
#  $Id$
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
class Arrow::Path
	include Enumerable,
	        Arrow::Loggable,
	        Arrow::Constants

	extend Forwardable


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The character to split path Strings on, and join on when
	# converting back to a String.
	SEPARATOR = File::PATH_SEPARATOR

	# How many seconds to cache directory stat information, in seconds.
	DEFAULT_CACHE_LIFESPAN = 1.5


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Return the YAML type for this class
	def self::to_yaml_type
		"!%s/arrowPath" % [ Arrow::Constants::YAML_DOMAIN ]
	end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Path object for the specified +path+, which can
	### be either a String containing directory names separated by
	### File::PATH_SEPARATOR, an Array of directory names, or an object
	### which returns such an Array when #to_a is called on it. If
	### +cache_lifespan+ is non-zero, the Array of valid directories will be
	### cached for +cache_lifespan+ seconds to save calls to stat().
	def initialize( path=[], cache_lifespan=DEFAULT_CACHE_LIFESPAN )
		@dirs = case path
				when Array
					path.flatten
				when String
					path.split(SEPARATOR)
				else
					path.to_a.flatten
				end

		@dirs.collect! {|dir| dir.untaint.to_s }

		@valid_dirs = []
		@cache_lifespan = cache_lifespan
		@last_stat = Time.at(0)
	end


	######
	public
	######

	# The raw list of directories contained in the path, including invalid
	# (non-existent or unreadable) ones.
	attr_accessor :dirs

	# How long (in seconds) to cache the list of good
	# directories. Setting this to 0 turns off caching.
	attr_accessor :cache_lifespan


	### Fetch the list of valid directories, using a cached value if the
	### path has caching enabled (which is the default). Otherwise, it
	### fetches the valid list via #find_valid_dirs and caches the result
	### for #cache_lifespan seconds. If caching is disabled, this is
	### equivalent to just calling #find_valid_dirs.
	def valid_dirs
		if ( @cache_lifespan.nonzero? &&
			 ((Time.now - @last_stat) < @cache_lifespan) )
			self.log.debug "Returning cached dirs."
			return @valid_dirs
		end

		@valid_dirs = self.find_valid_dirs
		@last_stat = Time.now

		return @valid_dirs
	end


	### Fetch the list of paths in the search path, vetted to only contain
	### those that are not tainted, exist, are directories, are readable
	### by the current user, and are not world-writable.
	def find_valid_dirs
		return @dirs.find_all do |dir|
			if dir.tainted?
				self.log.info "Discarding tainted directory entry %p" % [ dir ]
				next
			end

			path = Pathname.new( dir )

			if ! path.exist?
				self.log.debug "Discarding non-existant path: %s" % [ path ]
				next false
			elsif ! path.directory?
				self.log.debug "Discarding non-directory: %s" % [ path ]
				next false
			elsif ! path.readable?
				self.log.debug "Discarding unreadable directory: %s" % [ path ]
				next false
			elsif( (path.stat.mode & 0002).nonzero? )
				self.log.debug "Discarding world-writable directory: %s" % [ path ]
				next false
			end
			
			true
		end.map {|pn| pn.to_s }
	end
	

	# Generate Array-ish methods that delegate to self.dirs
	def_delegators :@dirs,
		*(Array.instance_methods(false) -
		Enumerable.instance_methods(false) -
		[:to_yaml, :inspect, :to_s])
			

	### Enumerable interface method. Iterate over the list of valid dirs
	### in this path, calling the specified block for each.
	def each( &block )
		self.valid_dirs.each( &block )
	end


	### Return the path as a <tt>SEPARATOR</tt>-separated String.
	def to_s
		return self.valid_dirs.join( SEPARATOR )
	end


	### Return the path as YAML text
	def to_yaml( opts={} )
		require 'yaml'
		YAML.quick_emit( self.object_id, opts ) {|out|
			out.seq( self.class.to_yaml_type ){|seq|
				seq.add( self.dirs )
			}
		}
	end

end # class Arrow::Path


