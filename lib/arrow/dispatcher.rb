#!/usr/bin/ruby
# 
# This file contains the Arrow::Dispatcher class, which the mod_ruby handler
# frontend for a web application.
# 
# == Synopsis
# 
#	RubyRequire 'arrow'
#
#   <Location /myapp>
#		Handle ruby-object
#		RubyHandler Arrow::Dispatcher::create( 'myapp.yaml' )
#	</Location>
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

require 'arrow/object'
require 'arrow/config'
require 'arrow/applet'
require 'arrow/transaction'
require 'arrow/broker'
require 'arrow/template'
require 'arrow/factories'
require 'arrow/session'

module Arrow

	### A mod_ruby handler class for dispatching requests to an Arrow web
	### application.
	class Dispatcher < Arrow::Object

		@@Instance = nil

		### Class constants
		Version = /([\d\.]+)/.match( %q{$Revision: 1.10 $} )[1]
		Rcsid = %q$Id: dispatcher.rb,v 1.10 2004/01/26 05:46:50 deveiant Exp $

		### Create a new Arrow::Dispatcher object.
		def self::create( configfile=nil )
			return @@Instance unless @@Instance.nil?

			# Set up logging
			if Arrow::Logger::global.outputters.empty?
				outputter = Arrow::Logger::Outputter::create( 'apache' )
				Arrow::Logger::global.outputters << outputter
				Arrow::Logger::global.level = :notice
				Arrow::Logger[Arrow::Template].level = :notice
			end

			# If a config file is given, load it. If it's not, just use the
			# default config.
			Arrow::Logger.notice "Arrow config file is %p" % configfile
			if configfile
				config = Arrow::Config::load( configfile )
			else
				config = Arrow::Config::new
			end

			# Create and return the dispatcher
 			@@Instance = new( config )
		rescue ::Exception => err
			Apache::request.server.log_crit( "%s failed to start (%s): %s: %s",
				self.name,
				err.class.name,
				err.message,
				err.backtrace.join("\n  ") )
			Kernel::raise( err )
		end


		### Set up an Arrow::Dispatcher object based on the specified +config+
		### (an Arrow::Config object).
		def initialize( config )
			@config = config
			@broker = nil

			if !Apache::Request::respond_to?( :libapreq? ) ||
					!Apache::Request::libapreq?
				raise "mod_ruby is not compiled with libapreq"
			end

			self.configure( config )
		rescue ::Exception => err
			msg = "%s while creating dispatcher: %s\n%s" %
				[ err.class.name, err.message, err.backtrace.join("\n\t") ]
			self.log.error( msg )
			Apache::request.server.log_crit( msg )
		end


		######
		public
		######

		### (Re)configure the dispatcher based on the values in the given
		### +config+ (an Arrow::Config object).
		def configure( config )

			self.log.notice "Configuring a dispatcher for '%s': child server %d" %
				[ Apache::request.server.hostname, Process::pid ]

			# Start the monitor backend if they're configured
			if config.startMonitor?
				self.log.notice "Starting Monitor backend"
				Arrow::Monitor::startBackend( config )
			else
				self.log.notice "Monitor skipped by configuration"
			end

			# Set up the logging level
			self.log.notice "Setting global log level to %p" %
				config.logLevel.to_s.intern
			Arrow::Logger.global.level = config.logLevel.to_s.intern
			Arrow::Logger[ Arrow::Template ].level =
				config.templateLogLevel.to_s.intern

			# Set up the session class
			self.log.notice "Configuring the Session class with %p" % config
			Arrow::Session::configure( config )

			# Create a new broker to handle applets
			self.log.notice "Creating request broker"
			@broker = Arrow::Broker::new( config )
		end


		### The content handler method. Dispatches requests to registered
		### applets based on the requests PATH_INFO.
		def handler( req )
			self.log.debug "Dispatching request %p " % req

			# Make sure the configuration hasn't changed and reload it if it has
			if @config.changed?
				self.log.notice "Reloading configuration"
				@config.reload
				self.configure( @config )
			end

			# Make sure there's a broker
			if ! @broker
				self.log.error "Fatal: No broker."
				return Apache::SERVER_ERROR
			end

			# Create the transaction
			txn = Arrow::Transaction::new( req, @config, @broker )

			# Let the broker decide what applet should get the transaction and
			# pass it off for handling.
			self.log.debug "Delegating transaction %p" % txn
			output = @broker.delegate( txn )
			# self.log.debug "Output = %p" % output

			# If the response succeeded, set up the Apache::Request object, add
			# headers, add session state, etc. If it failed, just log the failure.
			if txn.status == Apache::OK
				self.log.debug "Transaction has OK status"

				# Render the output before anything else, as there might be
				# session/header manipulation left to be done.
				outputString = output.to_s if output && output != true

				# If the transaction has a session, save it
				if txn.session?
					self.log.debug "Saving session state"
					txn.session.save
				end

				#req.header_out( 'Cache-Control', "max-age=5" )
				#req.header_out( 'Expires', (Time::now + 5).strftime( )
				req.cache_resp = true

				req.sync = true
				req.send_http_header
				req.print( outputString ) if outputString
			else
				self.log.notice "Transaction has non-OK status: %d" %
					txn.status
			end

			self.log.debug "Returning status %d" % txn.status
			return txn.status
		rescue ::Exception => err
			self.log.error "Transaction Manager Error: %s:\n\t%s" %
				[ err.message, err.backtrace.join("\n\t") ]
			return Apache::SERVER_ERROR
		end

		#########
		protected
		#########

			

	end # class Dispatcher

end # module Arrow

