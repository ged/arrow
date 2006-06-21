#!/usr/bin/ruby
# 
# This file contains the Arrow::Dispatcher class, which is the mod_ruby handler
# frontend for a web application.
# 
# == Synopsis
# 
# Simple configuration:
#
#	RubyRequire 'arrow'
#   RubyChildInitHandler "Arrow::Dispatcher.create( 'myapp.yaml' )"
#
#   <Location /arrow>
#       Handler ruby-object
#		RubyHandler Arrow::Dispatcher.instance
#	</Location>
#
# More-complex setup; run two Arrow dispatchers with different configurations
# from different Locations:
#
#	RubyRequire 'arrow'
#   RubyChildInitHandler "Arrow::Dispatcher.create( :myapp => 'myapp.yml', :help => 'help.yml' )"
#
#   <Location /myapp>
#		Handler ruby-object
#		RubyHandler Arrow::Dispatcher.instance(:myapp)
#	</Location>
# 
#   <Location /help>
#		Handler ruby-object
#		RubyHandler Arrow::Dispatcher.instance(:help)
#	</Location>
# 
# Same thing, but use a YAML file to control the dispatchers and where their configs are:
#
#	RubyRequire 'arrow'
#   RubyChildInitHandler "Arrow.load_dispatchers('/Library/WebServer/arrow-hosts.yml')"
#
#   <Location /myapp>
#		Handler ruby-object
#		RubyHandler Arrow::Dispatcher.instance(:myapp)
#	</Location>
# 
#   <Location /help>
#		Handler ruby-object
#		RubyHandler Arrow::Dispatcher.instance(:help)
#	</Location>
#
# arrow-hosts.yml:
#
#   myapp:
#     /some/directory/myapp.yml
#   help:
#     /other/directory/help.yml
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

require 'tmpdir'

require 'arrow/object'
require 'arrow/config'
require 'arrow/applet'
require 'arrow/transaction'
require 'arrow/broker'
require 'arrow/template'
require 'arrow/templatefactory'
require 'arrow/session'

require 'arrow/fallbackhandler'


### A mod_ruby handler class for dispatching requests to an Arrow web
### application.
class Arrow::Dispatcher < Arrow::Object

	@@Instance = {}

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	private_class_method :new


	### Set up one or more new Arrow::Dispatcher objects. The +configspec+
	### argument can either be the path to a config file, or a hash of config
	### files. See the .instance method for more about how to use this method.
	def self::create( configspec )

		# Normalize configurations. Expected either a configfile path in a
		# String, or a Hash of configfiles
		case configspec
		when String
			configs = { :__default__ => configspec }
		when Hash
			configs = configspec
		else
			raise ArgumentError, "Invalid config hash %p" % configspec
		end

		# Create the dispatchers and return the first one to support the
		# old-style create, i.e.,
		#   dispatcher = Arrow::Dispatcher.create( configfile )
		@@Instance = create_configured_dispatchers( configs )
		@@Instance.values.first
	rescue ::Exception => err

		# Try to log fatal errors to both the Apache server log and a crashfile
		# before passing the exception along.
		errmsg = "%s failed to start (%s): %s: %s" % [
			self.name,
			err.class.name,
			err.message,
			err.backtrace.join("\n  ")
		]

		logfile = File.join( Dir.tmpdir, "arrow-fatal.log.#{$$}" )
		File.open( logfile, IO::WRONLY|IO::TRUNC|IO::CREAT ) {|ofh|
			ofh.puts( errmsg )
			ofh.flush
		}

		if defined?( Apache )
			Apache.request.server.log_crit( errmsg )
		end

		Kernel.raise( err )
	end


	### Get the instance of the Dispatcher set up under the given +key+, which
	### can either be a Symbol or a String containing the path to a
	### configfile. If no key is given, it defaults to :__default__, which is
	### the key assigned when .create is given just a configfile argument.
	def self::instance( key=:__default__ )
		rval = nil

		# Fetch the instance which corresponds to the given key
		if key.is_a?( Symbol )
			Arrow::Logger.debug "Returning instance for key %p (one of %p): %p" %
				[key, @@Instance.keys, @@Instance[key]]
			rval = @@Instance[ key ]
		else
			Arrow::Logger.debug "Returning instance for configfile %p" % [key]
			configfile = File.expand_path( key )
			self.create( configfile )
			rval = @@Instance[ configfile ]
		end

		# Return either a configured Dispatcher instance or a FallbackHandler if
		# no Dispatcher corresponds to the given key.
		return rval || Arrow::FallbackHandler.new( key, @@Instance )
	end


	### Create dispatchers for the config files given in +configspec+ and return
	### them in a Hash keyed by both the configname key and the expanded path to
	### the configuration file.
	def self::create_configured_dispatchers( configspec )
		instances = {}

		# Load a dispatcher for each config
		configspec.each do |key, configfile|

			# Normalize the path to the config file and make sure it's not
			# loaded yet. If it is, link it to the current key and skip to the
			# next.
			configfile = File.expand_path( configfile )
			if instances.key?( configfile )
				instances[ key ] = instances[ configfile ]
				next
			end

			# If a config file is given, load it. If it's not, just use the
			# default config.
			if configfile
				config = Arrow::Config.load( configfile )
			else
				config = Arrow::Config.new
			end

			# Create a dispatcher and put it in the table by both its key and
			# the normalized path to its configfile.
			instances[ key ] = instances[ configfile ] = new( key, config )
		end

		return instances
	end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Set up an Arrow::Dispatcher object based on the specified +config+
	### (an Arrow::Config object).
	def initialize( name, config )
		@name = name
		@config = config
		@broker = nil

		self.configure( config )
	rescue ::Exception => err
		msg = "%s while creating dispatcher: %s\n%s" %
			[ err.class.name, err.message, err.backtrace.join("\n\t") ]
		self.log.error( msg )
		Apache.request.server.log_crit( msg ) unless !defined?( Apache )
	end


	######
	public
	######

	### The key used to indentify this dispatcher
	attr_reader :name
	

	### (Re)configure the dispatcher based on the values in the given
	### +config+ (an Arrow::Config object).
	def configure( config )

		self.log.notice "Configuring a dispatcher for '%s' from '%s': child server %d" %
			[ Apache.request.server.hostname, config.name, Process.pid ]

        # Configure any modules that have mixed in Arrow::Configurable
        Arrow::Configurable.configure_modules( config, self )

		# Start the monitor backend if enabled
		if config.startMonitor?
			self.log.info "Starting Monitor backend"
			Arrow::Monitor.startBackend( config )
		else
			self.log.info "Monitor skipped by configuration"
		end

		# Apache.request.server.log_notice( "Loggers: %p" % [Arrow::Logger.loggers] )

		# Set up the session class
		self.log.info "Configuring the Session class with %s" % [ config.name ]
		Arrow::Session.configure( config )

		# Create a new broker to handle applets
		self.log.info "Creating request broker"
		@broker = Arrow::Broker.new( config )
	end


	### mod_ruby Handlers

    ### Child init mod_ruby handler
    def child_init( req ) # :nodoc
        self.log.notice "Dispatcher configured for %s" % [ req.server.hostname ]
        return Apache::OK
    end

	### The content handler method. Dispatches requests to registered
	### applets based on the requests PATH_INFO.
	def handler( req )
		self.log.debug "--- Dispatching request %p ---------------" % req

		if @config.changed?
			self.log.notice "Reloading configuration "
			@config.reload
			self.configure( @config )
		end

		if ! @broker
			self.log.error "Fatal: No broker."
			return Apache::SERVER_ERROR
		end

		txn = Arrow::Transaction.new( req, @config, @broker )

		self.log.debug "Delegating transaction %p" % txn
		output = @broker.delegate( txn )
		# self.log.debug "Output = %p" % output

		# If the transaction succeeded, set up the Apache::Request object, add
		# headers, add session state, etc. If it failed, log the failure and let
		# the status be returned as-is.
		if txn.status == Apache::OK
			self.log.debug "Transaction has OK status"

			# Render the output before anything else, as there might be
			# session/header manipulation left to be done somewhere in the
			# render.
			outputString = output.to_s if output && output != true

			# If the transaction has a session, save it
			if txn.session?
				self.log.debug "Saving session state"
				txn.session.save
			end

			# :FIXME: Figure out what cache-control settings work
			#req.header_out( 'Cache-Control', "max-age=5" )
			#req.header_out( 'Expires', (Time.now + 5).strftime( )
			req.cache_resp = true

			req.sync = true
			req.send_http_header
			req.print( outputString ) if outputString
		else
			self.log.notice "Transaction has non-OK status: %d" %
				txn.status
		end

		self.log.debug "Returning status %d" % txn.status
		self.log.debug "--- Done with request %p ---------------" % req

		return txn.status
	rescue ::Exception => err
		self.log.error "Dispatcher caught an unhandled %s: %s:\n\t%s" %
			[ err.class.name, err.message, err.backtrace.join("\n\t") ]
		return Apache::SERVER_ERROR

	ensure
		# Make sure session locks are released
		if txn && txn.session?
			txn.session.finish
		end
	end


	### Return a human-readable representation of the receiver as a String.
	def inspect
		return "#<%s:0x%x config: %s>" % [
			self.class.name,
			self.object_id,
			@config.name,
		]
	end


end # class Arrow::Dispatcher

