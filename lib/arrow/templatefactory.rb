#!/usr/bin/env ruby

require 'arrow/mixins'
require 'arrow/object'
require 'arrow/exceptions'
require 'arrow/cache'

# The TemplateFactory class, which is responsible for
# interpreting the 'templates' section of the configuration, and providing 
# template-loading and -caching according to that configuration, 
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
class Arrow::TemplateFactory < Arrow::Object
	require 'arrow/template'


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Given an Arrow::Config object (+config+), attempt to load and
	### instantiate the configured template loader object.
	def self::build_template_loader( config )

		# Resolve the loader name into the Class object by traversing
		# constants.
		klass = config.templates.loader.
			split( /::/ ).
			inject( Object ) {|mod, name|
				mod.const_get( name ) or raise ConfigError,
					"No such template loader class #{name} for #{mod.name}"
			}

		if klass.respond_to?( :load, false )
			Arrow::Logger[ self ].debug "Loader (%s) class responds to ::load; using it directly: %p" %
				[ klass.name, klass.method(:load) ]
			return klass
		else
			Arrow::Logger[ self ].debug "Loader (%s) expects instantiation." % [ klass.name ]
			return klass.new( config )
		end
	end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new TemplateFactory from the given configuration object,
	### which should specify a loader class for templates.
	def initialize( config )
		@config = config
		@cache = nil
		
		if config.templates.cache
			@cache = Arrow::Cache.new(
				"Template Factory",
				config.templates.cacheConfig,
				&method(:template_expiration_hook) )
		end

		@loader = self.class.build_template_loader( config )
		@path = config.templates.path

		super()
	end


	######
	public
	######

	# The Arrow::Cache object used to cache template objects.
	attr_accessor :cache
	
	# The loader object that the factory uses to load templates
	attr_accessor :loader

	# The path to search for templates
	attr_accessor :path
	

	### Load a template object with the specified name.
	def get_template( name )
		self.log.debug "Fetching template '#{name}'"

		if @cache
			self.log.debug "Doing cached fetch."
			tmpl = @cache.fetch( name, &method(:load_from_file) )

			if tmpl.changed?
				self.log.debug "Template has changed on disk: reloading"
				@cache.invalidate( name )
				tmpl = @cache.fetch( name, &method(:load_from_file) )
			end

			return tmpl.dup
		else
			self.log.debug "Caching disabled. Loading from file."
			return self.load_from_file( name )
		end
	end


	### Load a template from its source file (ie., if caching is turned off
	### or if the cached version is either expired or not yet seen)
	def load_from_file( name )
		self.log.debug "Loading template #{name} from the filesystem"
		return @loader.load( name, @path )
	end


	### Called when a template is expired from the cache
	def template_expiration_hook( key, template )
		self.log.debug "Template %s is expiring." % key
	end
	
end # class Arrow::TemplateFactory


