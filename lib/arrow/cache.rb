#!/usr/bin/env ruby

require 'cache'
require 'forwardable'

require 'arrow/logger'
require 'arrow/mixins'


# 
# A derivative of the Cache class from the ruby-cache module. It adds a few 
# convenience and introspection methods to its parent.
# 
# Instances of this class are LRU caches for disk-based objects which keep
# track of the cached object's modification time, expiring the cached
# version when the disk-based version changes (e.g., for template caching).
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
class Arrow::Cache < ::Cache
	extend Forwardable
	include Arrow::Loggable

	# Default configuration values
	DefaultConfig = {
		:maxNum			=> 10,
		:maxObjSize		=> nil,
		:maxSize		=> nil,
		:expiration		=> 3600,
	}

	
	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	@extent = []
	class << self
		attr_reader :extent
	end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new cache. This merges the DefaultConfig with the specified
	### values and transforms camelCased keys into under_barred ones.
	def initialize( name, config={}, &cleanup )
		@name = name

		# Merge defaults and specified values
		merged = DefaultConfig.merge( config )

		# Transform the config hash into the form the superclass expects
		merged.each_key do |key|
			lckey = key.to_s.gsub( /(.)([A-Z])/ ) {|match|
				match[0,1] + "_" + match[1,1].downcase
			}.to_sym

			next if key == lckey
			merged[ lckey ] = merged.delete( key )
		end

		# Register this instance with the class for introspection (costs
		# much less than ObjectSpace.each_object).
		obj = super( merged, &cleanup )
		self.class.extent << obj

		return obj
	end


	######
	public
	######
	
	# Delegate some methods to the underlying hash
	def_delegators :@objs, :length, :keys, :values
	

	# The name of the cache; used in introspection
	attr_reader :name
	
	# Total count of cache hits
	attr_reader :hits
	
	# Total count of cache misses
	attr_reader :misses
	
	# Cache size in bytes
	attr_reader :size
	
	# The list of cached objects
	attr_reader :list


	### Overridden to provide logging of invalidated keys.
	def invalidate( key )
		self.log.debug "invalidating cache key '%p' for %s" % [key, self.name]
		super
	end


	### Overridden for logging.
	def invalidate_all
		self.log.debug "invalidating all cached objects for %s" % [self.name]
		super
	end
	

	### Overridden to provide logging of expire phase.
	def expire
		self.log.debug "looking for expired entries in %s" % [self.name]
		super
	end


	### Overridden from the superclass to prevent .to_s from being called on
	### objects to determine their size if the object supports a #memsize
	### method. This is mostly to stop templates from being rendered every
	### time they're cached.
	def []=( key, obj )
		self.expire
		
		self.invalidate( key ) if self.cached?( key )

		if obj.respond_to?( :memsize )
			size = obj.memsize
		else
			size = obj.to_s.size
		end

		# Test against size threshold
		if @max_obj_size && size > @max_obj_size
			Arrow::Logger[self.class].debug \
				"%p not cached: size exceeds maxObjSize: %d" %
				[ obj, @max_obj_size ]
			return obj
		end
		if @max_obj_size.nil? && @max_size && size > @max_size
			Arrow::Logger[self.class].debug \
				"%p not cached: size exceeds maxSize: %d" %
				[ obj, @max_size ]
			return obj
		end
		
		if @max_num && @list.size >= @max_num
			Arrow::Logger[self.class].debug \
				"Dropping %p from the cache: count exceeds maxNum: %d" %
				[ @list.first, @max_num ]
			self.invalidate( @list.first )
		end

		@size += size
		if @max_size
			while @size > @max_size
				Arrow::Logger[self.class].debug \
					"Dropping %p from the cache: size exceeds maxSize: %d" %
					[ @list.first, @max_size ]
				self.invalidate( @list.first )
			end
		end

		@objs[ key ] = Cache::CACHE_OBJECT.new( obj, size, Time.now.to_i )
		@list.push( key )

		return obj
	end


end # class Arrow::Cache
