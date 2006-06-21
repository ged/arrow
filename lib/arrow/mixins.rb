#!/usr/bin/ruby
# 
# This file contains mixins which are used throughout the Arrow framework:
#
# == Arrow::Loggable
#    A mixin that adds a #log method to including classes that calls
#    Arrow::Logger with the class of the receiving object.
#
# === Usage
# 
#   require "arrow/mixins"
#
#   class MyClass
#     include Arrow::Loggable
#	end
# 
# == Arrow::Configurable
#    A mixin that collects classes that expect to be configured by an 
#    Arrow::Config instance.
#
# === Usage
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
# == Arrow::Injectable
#
# Adds dependency-injection bejavior to a class. Classes which are Injectable
# are loadable by name, making it easier to refer to them from a configuration
# file or other symbolic source. Instead of classes explicitly referring to 
# one another to satisfy their associations, these dependencies can be 
# "injected" at runtime.
#
# Some references for the Dependency Injection pattern:
#
#  * http://www.martinfowler.com/articles/injection.html
#  * http://en.wikipedia.org/wiki/Dependency_injection
#
# === Usage
# 
#   # in myclass.rb
#   require 'arrow/mixins'
#
#   class MyClass
#     include Arrow::Injectable
#   end
#
#   # somewhere else
#   myclass = Arrow::Injectable.load_class( "myclass" )
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
		###	A P P E N D E D   M E T H O D S
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



	### A mixin for adding injectability to a data class. Classes which 
	### include this module can be loaded by name via Injectable.load_class, 
	### and will be collected in Injectable.derivatives when they load.
	module Injectable

		@derivatives = {}
		def self::derivatives; @derivatives; end

		### Make the given object (which must be a Class) injectable.
		def self::extend_object( obj )
			raise ArgumentError, "can't make a #{obj.class} Configurable" unless
				obj.is_a?( Class )
			super
			@derivatives[ obj.name ] = obj
		end


		### Mixin hook: extend including classes
		def self::included( mod )
			Arrow::Logger[self].debug "%s included Injectable" % [ mod.name ]
			mod.extend( self )
			super
		end
		
		
		### Return the Class object for the given derivative +classname+, 
		### attempting to load it if it hasn't been already.
		def self::load_class( classname )
			Arrow::Logger[self].debug "Loading class '#{classname}'"
			
			unless Arrow::Injectable.derivatives.include?( classname )
				modname = classname.downcase.gsub( /::/, '/' )
				Arrow::Logger[self].debug "Class loaded yet. Trying to " +
					"load it from #{modname}"
				require modname
				Arrow::Logger[self].debug "Loaded %s: %p" %
					[ classname, Arrow::Injectable.derivatives ]
			end

			Arrow::Injectable.derivatives[ classname ]
		end


		#############################################################
		###	A P P E N D E D   M E T H O D S
		#############################################################

		### Classes which inherit from Injectable classes should be
        ### Injectable, too.
		def inherited( klass )
			Arrow::Logger[self].debug "making %s Injectable" % [ klass.name ]
			Arrow::Injectable.derivatives[ klass.name ] = klass
			super
		end
		
	end # module Injectable


	
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
