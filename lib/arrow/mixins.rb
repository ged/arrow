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

