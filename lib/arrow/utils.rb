#!/usr/bin/env ruby
# 
# This file contains various utility classes, modules, and functions that don't
# really fit anywhere else. It also adds some stuff to several built-in classes.
# 
# The following classes will be available after requiring 'arrow/utils':
#
# [<tt>Arrow::Path</tt>]
#   A class for representing directory search paths.
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

require 'rbconfig'
require 'forwardable'
require 'pathname'

require 'arrow/monkeypatches'
require 'arrow/constants'
require 'arrow/mixins'
require 'arrow/exceptions'

module Arrow

	# Recursive hash-merge function
	HashMergeFunction = Proc.new {|key, oldval, newval|
		#debugMsg "Merging '%s': %s -> %s" %
		#	[ key.inspect, oldval.inspect, newval.inspect ]
		case oldval
		when Hash
			case newval
			when Hash
				#debugMsg "Hash/Hash merge"
				oldval.merge( newval, &HashMergeFunction )
			else
				newval
			end

		when Array
			case newval
			when Array
				#debugMsg "Array/Array union"
				oldval | newval
			else
				newval
			end

		when Arrow::Path
			if newval.is_a?( Arrow::Path )
				newval
			else
				Arrow::Path.new( newval )
			end

		else
			newval
		end
	}


	### A class for representing directory search paths.
	class Path
		include Enumerable, Arrow::Loggable
		extend Forwardable

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# The character to split path Strings on, and join on when
		# converting back to a String.
		Separator = File::PATH_SEPARATOR

		# How many seconds to cache directory stat information, in seconds.
		DefaultCacheLifespan = 1.5


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Return the YAML type for this class
		def self::to_yaml_type
			"!%s/arrowPath" % Arrow::YAML_DOMAIN
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
		def initialize( path=[], cache_lifespan=DefaultCacheLifespan )
			@dirs = case path
					when Array
						path.flatten
					when String
						path.split(Separator)
					else
						path.to_a.flatten
					end

			@dirs.each {|dir| dir.untaint}

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


		### Fetch the list of directories in the search path, vetted to only
		### contain existent and readable ones. All the enumeration methods
		### use this list.
		def valid_dirs
			if ( @cache_lifespan.nonzero? &&
				 ((Time.now - @last_stat) < @cache_lifespan) )
				self.log.debug "Returning cached dirs."
				return @valid_dirs
			end

			@valid_dirs = @dirs.find_all do |dir|
				if dir.tainted?
					self.log.info "Discarding tainted directory entry %p" % [ dir ]
					next
				end

				begin
					stat = File.stat(dir)
					if stat.directory? && stat.readable?
						true
					else
						self.log.debug "Discarded unreadable or non-directory %s" %
							dir
						false
					end
				rescue Errno::ENOENT => err
					self.log.notice "Discarded invalid directory %p: %s" %
						[ dir, err.message ]
					false
				rescue ::SecurityError => err
					self.log.error "Discarded unsafe directory %p: %s" %
						[ dir, err.message ]
				end
			end
			@last_stat = Time.now

			return @valid_dirs
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


		### Return the path as a <tt>PathSeparator</tt>-separated String.
		def to_s
			return self.valid_dirs.join( Separator )
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

	end # class Path


	###############
	module_function
	###############

	### Search for and require ruby module files from subdirectories of the
	### $LOAD_PATH specified by +subdir+. If excludePattern is a Regexp or a
	### String, it will be used as a pattern to exclude matching module files.
	def require_all_from_path( subdir="arrow", excludePattern=nil )
		excludePattern = Regexp::compile( excludePattern.to_s ) unless
			excludePattern.nil? || excludePattern.is_a?( Regexp )

		subdir = Pathname.new( subdir ) unless subdir.is_a?( Pathname )

		$LOAD_PATH.
			collect {|dir| Pathname.new(dir) + subdir }.
			find_all {|dir| dir.directory? }.
			inject([]) {|files,dir|
				files += dir.entries.find_all {|file|
					/^[-.\w]+\.(rb|#{Config::CONFIG['DLEXT']})$/.match( file )
				}
			}.
			uniq.
			reject {|file| 
				excludePattern.match(file) unless excludePattern.nil?
			}.
			each do |file|
				require subdir + file
			end
	end

end # module Arrow


