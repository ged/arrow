#!/usr/bin/ruby
# 
# This file contains the Arrow::Object and Arrow::Version classes. Arrow::Object is
# the base class for all objects in Arrow. Arrow::Version is a Comparable version
# object class that is used to represent class versions.
# 
# == Synopsis
# 
#   require 'arrow/object'
#
#   module Arrow
#     class MyClass < Arrow::Object
#       def initialize( *args )
#         super()
#       end
#     end
#   end
# 
# == Rcsid
# 
# $Id: object.rb,v 1.6 2004/01/18 21:04:23 deveiant Exp $
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

require 'arrow/utils'


### A couple of syntactic sugar aliases for the Module class.
###
### [<tt>Module::implements</tt>]
###     An alias for <tt>include</tt>. This allows syntax of the form:
###       class MyClass < Arrow::Object; implements Arrow::Debuggable, AbstracClass
###         ...
###       end
###
### [<tt>Module::implements?</tt>]
###     An alias for <tt>Module#<</tt>, which allows one to ask
###     <tt>SomeClass.implements?( Debuggable )</tt>.
###
class Module

	# Syntactic sugar for mixin/interface modules.  (Borrowed from Hipster's
	# component "conceptual script" - http://www.xs4all.nl/~hipster/)
	alias :implements :include
	alias :implements? :include?
end


require 'arrow/exceptions'
require 'arrow/mixins'
require 'arrow/logger'

module Arrow

	### This class is the abstract base class for all Arrow objects. Most of the
	### Arrow classes inherit from this.
	class Object < ::Object

		include Loggable

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.6 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: object.rb,v 1.6 2004/01/18 21:04:23 deveiant Exp $


		### Create a method that warns of deprecation for an instance method. If
		### <tt>newSym</tt> is specified, the method is being renamed, and this
		### method acts like an <tt>alias_method</tt> that logs a warning; if
		### not, it is being removed, and the target method will be aliased to
		### an internal method and wrapped in a warning method with the original
		### name.
		def self::deprecate_method( oldSym, newSym=oldSym )
			warningMessage = ''

			# If the method is being removed, alias it away somewhere and build
			# an appropriate warning message. Otherwise, just build a warning
			# message.
			if oldSym == newSym
				newSym = ("__deprecated_" + oldSym.to_s + "__").intern
				warningMessage = "%s#%s is deprecated" %
					[ self.name, oldSym.to_s ]
				alias_method newSym, oldSym
			else
				warningMessage = "%s#%s is deprecated; use %s#%s instead" %
					[ self.name, oldSym.to_s, self.name, newSym.to_s ]
			end
			
			# Build the method that logs a warning and then calls the true
			# method.
			class_eval %Q{
				def #{oldSym.to_s}( *args )
					self.log.warning "warning: %s: #{warningMessage}" % caller(1)
					send( #{newSym.inspect}, *args )
				rescue => err
					# Mangle exceptions to point someplace useful
					Kernel::raise err, err.message, err.backtrace[2..-1]
				end
			}
		rescue Exception => err
			# Mangle exceptions to point someplace useful
			frames = err.backtrace
			frames.shift while frames.first =~ /#{__FILE__}/
			Kernel::raise err, err.message, frames
		end


		### Like Object::deprecate_method, but for class methods.
		def self::deprecate_class_method( oldSym, newSym=oldSym )
			warningMessage = ''

			# If the method is being removed, alias it away somewhere and build
			# an appropriate warning message. Otherwise, just build a warning
			# message.
			if oldSym == newSym
				newSym = ("__deprecated_" + oldSym.to_s + "__").intern
				warningMessage = "%s::%s is deprecated" %
					[ self.name, oldSym.to_s ]
				alias_class_method newSym, oldSym
			else
				warningMessage = "%s::%s is deprecated; use %s::%s instead" %
					[ self.name, oldSym.to_s, self.name, newSym.to_s ]
			end
			
			# Build the method that logs a warning and then calls the true
			# method.
			class_eval %Q{
				def self.#{oldSym.to_s}( *args )
					Arrow::Logger.warning "warning: %s: #{warningMessage}" % caller(1)
					send( #{newSym.inspect}, *args )
				rescue => err
					# Mangle exceptions to point someplace useful
					Kernel::raise err, err.message, err.backtrace[2..-1]
				end
			}
		end


		### Store the name of the file from which the inheriting +klass+ is
		### being loaded.
		def self::inherited( klass )
			unless klass.instance_variables.include?( "@sourcefile" )
				sourcefile = caller(1).find {|frame|
					/inherited/ !~ frame
				}.sub( /^([^:]+):.*/, "\\1" )
				klass.instance_variable_set( "@sourcefile", sourcefile )
			end

			unless klass.respond_to?( :sourcefile )
				class << klass
					attr_reader :sourcefile
				end
			end
		end


	end # class Object

end # module Arrow

