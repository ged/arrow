#!/usr/bin/ruby
# 
# This file contains various factory classes for Arrow.
# 
# == Rcsid
# 
# $Id: factories.rb,v 1.3 2003/11/18 05:40:32 deveiant Exp $
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

require 'arrow/mixins'
require 'arrow/object'
require 'arrow/exceptions'
require 'arrow/cache'

module Arrow

	### AbstractFactory for templates -- defer specification of which templating
	### system to use until load time, and provide timestamp-based caching for
	### template files.
	class TemplateFactory < Arrow::Object

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.3 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: factories.rb,v 1.3 2003/11/18 05:40:32 deveiant Exp $


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Given an Arrow::Config object (+config+), attempt to load and
		### instantiate the configured template loader object.
		def self::buildTemplateLoader( config )

			# Resolve the loader name into the Class object by traversing
			# constants.
			klass = config.templates.loader.
				split( /::/ ).
				inject( Object ) {|mod, name|
					mod.const_get( name ) or raise ConfigError,
						"No such template loader class #{name} for #{mod.name}"
				}

			if klass.respond_to?( :load )
				return klass
			else
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
			@cache = Arrow::Cache::new(
				"Template Factory",
				config.templates.cacheConfig,
				&method(:templateExpirationHook) )
			@templateLoader = self.class.buildTemplateLoader( config )

			Arrow::Template.loadPath = @config.templates.path

			super()
		end


		######
		public
		######

		# The Arrow::Cache object used to cache template objects.
		attr_reader :cache


		### Load a template object with the specified name.
		def getTemplate( name )
			self.log.debug "Fetching template '#{name}'"
			tmpl = @cache.fetch( name, &method(:loadFromFile) )

			if tmpl.changed?
				self.log.debug "Template has changed on disk: reloading"
				tmpl = @cache[ name ] = self.loadFromFile( name )
			end

			return tmpl.dup
		end


		### Load a template from its source file (ie., if caching is turned off
		### or if the cached version is either expired or not yet seen)
		def loadFromFile( name )
			self.log.debug "Loading template #{name}"
			@templateLoader.load( name )
		end


		### Called when a template is expired from the cache
		def templateExpirationHook( key, template )
			self.log.info "Template %s is expiring." % key
		end
		
	end # class TemplateFactory


end # module Arrow


