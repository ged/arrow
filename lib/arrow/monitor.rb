#!/usr/bin/ruby
# 
# This file contains the Arrow::monitor class. Instance of this class
# are used to monitor activity within an Arrow system.
# 
# == Synopsis
# 
#	require 'arrow/monitor'
#   require 'arrow/monitor/subjects'
#	require 'arrow/application'
#
#	class MyApp < Arrow::Application
#
#		# Register the application's monitoring subjects.
#		Arrow::Monitor::register( self,
#			:averageExecutionTimer => {
#				:description =>
#					"Average execution time of each application method.",
#				:type => AverageTimerTable,
#			},
#			:cumulativeRuntime => {
#				:description =>
#					"Total time used by this application.",
#				:type => TotalTimer,
#			} )
#
#		def execute( request )
#			Monitor[self].cumulativeRuntime.time do
#				super( request )
#			end
#		end
#
#		def method1( request, args )
#			Monitor[self].averageExecutionTimer.time( :method1 ) do
#				...
#			end
#		end
#   
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

require 'observer'
require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/object'

module Arrow

	### Instance of this class are used to monitor activity within an Arrow system..
	class Monitor < Object

		require 'arrow/monitor/subjects'

		### Class constants, instance variables, and methods
		Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]
		Rcsid = %q$Id: monitor.rb,v 1.1 2003/02/19 05:30:50 deveiant Exp $

		# The monitor instances that have been registered, keyed by the Modules
		# that registered them.
		@instances = {}


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		# Hide the 'new' method -- instantiation should be done through the
		# register method.
		private_class_method :new

		# Accessor for the instances hash
		class << self
			attr_accessor :instances
			protected :instances=
		end

		
		### Start the backend monitor server
		def self::startBackend( config )
			# No-op currently
			return false
		end


		### Register a +module+ with the monitoring system, specifying the
		### available monitoring subjects in the +subjectHash+.
		def self::register( mod, subjectHash )
			@instances[ mod ] = new( subjectHash )
		end


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Initialize an Arrow::Monitor object for the specified +mod+ and
		### +subjectHash+.
		def initialize( mod, subjectHash )
			@module = mod
			@subjects = {}

			subjectHash.each {|sym,config|
				subject = Monitor::Subject::create( config )
				@subjects[ sym ] = subject
			}
		end


		######
		public
		######

		

		#########
		protected
		#########


	end # class monitor

end # module Arrow
