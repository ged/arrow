#!/usr/bin/ruby
# 
# This file contains mixins which are used throughout the Arrow framework:
#
# [<tt>Arrow::Loggable</tt>]
#    A mixin that adds a #log method to including classes that calls
#    Arrow::Logger with the class of the receiving object.
#
# == Synopsis
# 
#   require "arrow/mixins"
#
#   class MyClass
#     include Arrow::Loggable
#	end
# 
# [<tt>Arrow::Configurable</tt>]
#    A mixin that collects classes that expect to be configured by an 
#    Arrow::Config instance.
#
# == Synopsis
# 
#   require "arrow/mixins"
#
#   class MyClass
#     include Arrow::Configurable
# 
#     config_key :myclass
#
#     def self::configure( config )
#       @@host = config.host
#     end
#	end
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

# Dependencies follow the module because of dependency loops.

# The module that serves as a namespace for all Arrow classes/mixins.
module Arrow

	### A mixin that adds configurability via an Arrow::Config object. 
	module Configurable

		@modules = []
		class << self
			attr_accessor :modules
		end
		

		### Make the given object (which must be a Module) configurable via
		### a section of an Arrow::Config object.
		def self::extend_object( obj )
			raise ArgumentError, "can't make a #{obj.class} Configurable" unless
				obj.is_a?( Module )

			super
			@modules << obj
		end


		### Generate a config key from the name of the given +klass+.
		def self::make_key_from_classname( klass )
			klass.name.sub( /^Arrow::/, '' ).gsub( /\W+/, '_' ).downcase.to_sym
		end
		

		### Mixin hook: extend including classes
		def self::included( mod )
			mod.extend( self )
			super
		end
		
		
		### Configure Configurable classes with the sections of the specified
		### +config+ that correspond to their +config_key+, if present.
		### (Undocumented)
		def self::configure_modules( config, dispatcher )
		    @modules.each do |mod|
		        key = mod.config_key
		        
		        if config.member?( key )
		            Arrow::Logger[ self ].debug \
		                "Configuring %s with the %s section of the config" %
		                [ mod.name, key ]
		            mod.configure( config[key], dispatcher )
	            else
	                Arrow::Logger[ self ].debug \
	                    "Skipping %s: no %s section in the config" %
		                [ mod.name, key ]
	            end
	        end
		end
		
		
		
		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################
		
		### The symbol which corresponds to the section of the configuration
		### used to configure the Configurable class.
		attr_writer :config_key

		### Get (and optionally set) the +config_key+.
		def config_key( sym=nil )
			@config_key = sym unless sym.nil?
			@config_key ||= Arrow::Configurable.make_key_from_classname( self )
			@config_key
		end
		
		### Default configuration method.
		def configure( config, dispatcher )
			raise NotImplementedError,
				"#{self.name} does not implement required method 'configure'"
		end

	end # module Configurable

	
	### A mixin that adds logging to its including class.
	module Loggable
		require 'arrow/logger'

		#########
		protected
		#########

		### Return the Arrow::Logger object for the receiving class.
		def log 
			Arrow::Logger[ self.class.name ] || Arrow::Logger.new( self.class.name )
		end

	end # module Loggable

	

end # module Arrow

require 'arrow/exceptions'
