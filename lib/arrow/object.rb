#!/usr/bin/env ruby

require 'arrow/path'
require 'arrow/exceptions'
require 'arrow/mixins'
require 'arrow/logger'


# This class is the abstract base class for all Arrow objects. Most of the
# Arrow classes inherit from this. 
# 
# == To Do
# 
# All of this stuff should really be factored out into mixins.
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Object < ::Object
	include Arrow::Loggable


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
			newSym = ("__deprecated_" + oldSym.to_s + "__").to_sym
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
			def #{oldSym.to_s}( *args, &block )
				self.log.notice "warning: %s: #{warningMessage}" % [ caller(1) ]
				send( #{newSym.inspect}, *args, &block )
			rescue => err
				# Mangle exceptions to point someplace useful
				Kernel.raise err, err.message, err.backtrace[2..-1]
			end
		}
	rescue Exception => err
		# Mangle exceptions to point someplace useful
		frames = err.backtrace
		frames.shift while frames.first =~ /#{__FILE__}/
		Kernel.raise err, err.message, frames
	end


	### Like Object.deprecate_method, but for class methods.
	def self::deprecate_class_method( oldSym, newSym=oldSym )
		warningMessage = ''

		# If the method is being removed, alias it away somewhere and build
		# an appropriate warning message. Otherwise, just build a warning
		# message.
		if oldSym == newSym
			newSym = ("__deprecated_" + oldSym.to_s + "__").to_sym
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
			def self::#{oldSym.to_s}( *args, &block )
				Arrow::Logger.notice "warning: %s: #{warningMessage}" % [ caller(1) ]
				send( #{newSym.inspect}, *args, &block )
			rescue => err
				# Mangle exceptions to point someplace useful
				Kernel.raise err, err.message, err.backtrace[2..-1]
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


end # class Arrow::Object

