#!/usr/bin/ruby
# 
# This file contains the Arrow::monitor class. Instance of this class
# are used to monitor activity within an Arrow system.
# 
# == Synopsis
# 
#   
# 
# == Rcsid
# 
# $Id: monitor.rb,v 1.1 2003/02/19 05:30:50 deveiant Exp $
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

require 'arrow'

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

		# Hide the 'new' method -- instantiation should be done through the
		# register method.
		private_class_method :new

		# Accessor for the instances hash
		class << self
			attr_accessor :instances
			protected :instances=
		end

		### Register a +module+ with the monitoring system, specifying the
		### available monitoring subjects in the +subjectHash+.
		def Monitor::register( mod, subjectHash )
			@instances[ mod ] = monitor = new( subjectHash )
		end


		### Create a new Arrow::Monitor object.
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

