#!/usr/bin/ruby
# 
# This file contains mixins which are used throughout the Arrow framework:
#
# [<tt>Arrow::TypeCheckFunctions</tt>]
#    A mixin that adds functions to the including class that are useful for
#    checking either the type or interface of a collection of objects.
#
# [<tt>Arrow::Factory</tt>]
#    A mixin that adds Factory design pattern-like behaviour to the including
#    class.
#
# == Synopsis
# 
#   require "arrow/mixins"
#
#   class MyClass
#     include Arrow::Factory, Arrow::TypeCheckFunctions
#	end
# 
# == Rcsid
# 
# $Id: mixins.rb,v 1.16 2004/03/14 01:47:23 stillflame Exp $
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

require 'pluginfactory'

# Dependencies follow the module because of dependency loops.

# The module that serves as a namespace for all Arrow classes/mixins.
module Arrow

	### Mixin that adds some type-checking functions to the current scope
	module TypeCheckFunctions

		###############
		module_function
		###############

		### Check <tt>anObject</tt> to make sure it's one of the specified
		### <tt>validTypes</tt>. If the object is not one of the specified value
		### types, and an optional block is given it is called with the object being
		### tested and the array of valid types. If no handler block is given, a
		### <tt>TypeError</tt> is raised.
		def checkType( anObject, *validTypes ) # :yields: object, *validTypes
			validTypes.flatten!
			validTypes.compact!

			unless validTypes.empty?

				### Compare the object against the array of valid types, and either
				### yield to the error block if given or generate our own exception
				### if not.
				unless validTypes.find {|type| anObject.kind_of?( type ) } then
					typeList = validTypes.collect {|type| type.name}.join(" or ")

					if block_given? then
						yield( anObject, [ *validTypes ].flatten )
					else
						raise TypeError, 
							"Argument must be of type #{typeList}, not a #{anObject.class.name}",
							caller(1).find_all {|frame| frame !~ /mixins\.rb/}
					end
				end
			else
				if anObject.nil? then
					if block_given? then
						yield( anObject, *validTypes )
					else
						raise ArgumentError, 
							"Argument missing.",
							caller(1).find_all {|frame| frame !~ /mixins\.rb/}
					end
				end
			end

			return true
		end


		### Check each object in the specified <tt>objectArray</tt> with a call to
		### #checkType with the specified validTypes array.
		def checkEachType( objectArray, *validTypes, &errBlock ) # :yields: object, *validTypes
			raise ScriptError, "First argument to checkEachType must be an array" unless
				objectArray.is_a?( Array )

			objectArray.each do |anObject|
				if block_given? then
					checkType anObject, validTypes, &errBlock
				else
					checkType( anObject, *validTypes ) {|obj, vTypes|
						typeList = vTypes.collect {|type| type.name}.join(" or ")
						raise TypeError, 
							"Argument must be of type #{typeList}, not a #{obj.class.name}",
							caller(1).find_all {|frame| frame !~ __FILE__}
					}
				end
			end

			return true
		end


		### Check <tt>anObject</tt> for implementations of <tt>requiredMethods</tt>.
		### If one of the methods is unimplemented, and an optional block is given it
		### is called with the method that failed the responds_to? test and the object
		### being checked. If no handler block is given, a <tt>TypeError</tt> is
		### raised.
		def checkResponse( anObject, *requiredMethods ) # yields method, anObject
			# Red: Throw away any nil types, and warn
			# Debug level might be inappropriate?
			os = requiredMethods.size
			requiredMethods.compact!
			debugMsg(1, "nil given in *requiredMethods") unless os == requiredMethods.size
			if requiredMethods.size > 0 then
				requiredMethods.each do |method|
					next if anObject.respond_to?( method )

					if block_given? then
						yield( method, anObject )
					else
						raise TypeError,
							"Argument '#{anObject.inspect}' does not answer the '#{method}()' method",
							caller(1).find_all {|frame| frame !~ __FILE__}
					end
				end
			end

			return true
		end


		### Check each object of <tt>anArray</tt> for implementations of
		### <tt>requiredMethods</tt>, calling the optional <tt>errBlock</tt> if
		### specified, or raising a <tt>TypeError</tt> if one of the methods is
		### unimplemented.
		def checkEachResponse( anArray, *requiredMethods, &errBlock ) # :yeilds: method, object
			raise ScriptError, "First argument to checkEachResponse must be an array" unless
				anArray.is_a?( Array )

			anArray.each do |anObject|
				if block_given? then
					checkResponse anObject, *requiredMethods, &errBlock
				else
					checkResponse( anObject, *requiredMethods ) {|method, object|
						raise TypeError,
							"Argument '#{anObject.inspect}' does not answer the '#{method}()' method",
							caller(1).find_all {|frame| frame !~ __FILE__}
					}
				end
			end

			return true
		end

	end # module TypeCheckFunctions


	# :MC: Moved out to its own module, keep all previous references to this the
	# same.
	Factory = PluginFactory


	### A mixin that adds logging to its including class.
	module Loggable

		require 'arrow/logger'

		#########
		protected
		#########

		### Return the Arrow::Logger object for the receiving class.
		def log 
			Arrow::Logger[ self.class.name ] || Arrow::Logger::new( self.class.name )
		end

	end

end # module Arrow

require 'arrow/exceptions'

