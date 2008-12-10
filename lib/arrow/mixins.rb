#!/usr/bin/env ruby
module Arrow

	require 'arrow/exceptions'
	
	### A collection of utilities for working with Hashes.
	module HashUtilities

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

		###############
		module_function
		###############

		### Return a version of the given +hash+ with its keys transformed
		### into Strings from whatever they were before.
		def stringify_keys( hash )
			newhash = {}

			hash.each do |key,val|
				if val.is_a?( Hash )
					newhash[ key.to_s ] = stringify_keys( val )
				else
					newhash[ key.to_s ] = val
				end
			end

			return newhash
		end


		### Return a duplicate of the given +hash+ with its identifier-like keys
		### transformed into symbols from whatever they were before.
		def symbolify_keys( hash )
			newhash = {}

			hash.each do |key,val|
				keysym = key.to_s.dup.untaint.to_sym

				if val.is_a?( Hash )
					newhash[ keysym ] = symbolify_keys( val )
				else
					newhash[ keysym ] = val
				end
			end

			return newhash
		end
		alias_method :internify_keys, :symbolify_keys

	end
	

	### A collection of utilities for working with Arrays.
	module ArrayUtilities

		###############
		module_function
		###############

		### Return a version of the given +array+ with any Symbols contained in it turned into
		### Strings.
		def stringify_array( array )
			return array.collect do |item|
				case item
				when Symbol
					item.to_s
				when Array
					stringify_array( item )
				else
					item
				end
			end
		end


		### Return a version of the given +array+ with any Strings contained in it turned into
		### Symbols.
		def symbolify_array( array )
			return array.collect do |item|
				case item
				when String
					item.to_sym
				when Array
					symbolify_array( item )
				else
					item
				end
			end
		end

	end
	

	### A collection of HTML utility functions
	module HTMLUtilities

		### Escape special characters in the given +string+ for display in an
		### HTML inspection interface. This escapes common invisible characters
		### like tabs and carriage-returns in additional to the regular HTML
		### escapes.
		def escape_html( string )
			return "nil" if string.nil?
			string = string.inspect unless string.is_a?( String )
			string.
				gsub(/&/, '&amp;').
				gsub(/</, '&lt;').
				gsub(/>/, '&gt;').
				gsub(/\n/, '&#8629;').
				gsub(/\t/, '&#8594;')
		end
		
	end # module HTMLUtiities


	# A mixin that collects classes that expect to be configured by an 
	# Arrow::Config instance.
	#
	# == Usage
	# 
	#	require "arrow/mixins"
	#
	#	class MyClass
	#	  include Arrow::Configurable
	# 
	#	  config_key :myclass
	#
	#	  def self::configure( config )
	#		@@host = config.host
	#	  end
	#	end
	# 
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
			unless klass.name == ''
				return klass.name.sub( /^Arrow::/, '' ).gsub( /\W+/, '_' ).downcase.to_sym
			else
				return :anonymous
			end
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
			
			# Have to keep messages from being logged before logging is 
			# configured.
			logmessages = []
			# logmessages << [
			# 	:debug, "Propagating config to Configurable classes: %p" %
			# 	[@modules] ]

			@modules.each do |mod|
				key = mod.config_key
				
				if config.member?( key )
					value = config.send( key )
					logmessages << [
						:debug, 
						"Configuring %s with the %s section of the config: %p" %
							[mod.name, key, value] ]

					if mod.method(:configure).arity == 2
						mod.configure( value, dispatcher )
					else
						mod.configure( value )
					end
				else
					logmessages << [
						:debug,
						"Skipping %s: no %s section in the config" %
						[mod.name, key] ]
				end
			end
			
			logmessages.each do |lvl, message|
				Arrow::Logger[ self ].send( lvl, message )
			end

			Arrow::Logger[ self ].debug "Propagated config to %d modules: %p" %
				[ @modules.length, @modules ]
			return @modules
		end
		
		
		#############################################################
		### A P P E N D E D	  M E T H O D S
		#############################################################

		### The symbol which corresponds to the section of the configuration
		### used to configure the Configurable class.
		attr_writer :config_key

		### :TODO:
		### * Change #config_key to #class_config_key and #instance_config_key
		### * Add a ::configure_instances method that would iterate over
		###   instances that had marked themselves as configurable in the same
		###   way the classed do now.


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
	# == Usage
	# 
	#	# in myclass.rb
	#	require 'arrow/mixins'
	#
	#	class MyClass
	#	  include Arrow::Injectable
	#	end
	#
	#	# somewhere else
	#	myclass = Arrow::Injectable.load_class( "myclass" )
	#
	#
	module Injectable

		@derivatives = {}
		def self::derivatives; @derivatives; end

		### Make the given object (which must be a Class) injectable.
		def self::extend_object( obj )
			raise ArgumentError, "can't make a #{obj.class} Injectable" unless
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
			Arrow::Logger[self].debug "Loading injectable class '#{classname}'"
			
			unless Arrow::Injectable.derivatives.include?( classname )
				modname = classname.downcase.gsub( /::/, '/' )
				Arrow::Logger[self].debug "Class not loaded yet. Trying to " +
					"load it from #{modname}"
				require modname or
					raise "%s didn't register with Injectable for some reason" % [ classname ]
				Arrow::Logger[self].debug "Loaded injectable class %s (%d classes loaded)" %
					[ classname, Arrow::Injectable.derivatives.length ]
			end

			Arrow::Injectable.derivatives[ classname ]
		end


		#############################################################
		### A P P E N D E D	  M E T H O D S
		#############################################################

		### Classes which inherit from Injectable classes should be
		### Injectable, too.
		def inherited( klass )
			Arrow::Logger[self].debug "making %s Injectable" % [ klass.name ]
			klass.extend( Arrow::Injectable )
			super
		end
		
	end # module Injectable

	
	# A mixin that adds a #log method to including classes that calls
	# Arrow::Logger with the class of the receiving object.
	#
	# == Usage
	# 
	#	require "arrow/mixins"
	#
	#	class MyClass
	#	  include Arrow::Loggable
	#	  
	#	  def some_method
	#	    self.log.debug "A debugging message"
	#	  end
	#	end
	# 
	module Loggable
		require 'arrow/logger'

		#########
		protected
		#########

		### Return the Arrow::Logger object for the receiving class.
		def log 
			Arrow::Logger[ self.class ]
		end

	end # module Loggable


end # module Arrow


