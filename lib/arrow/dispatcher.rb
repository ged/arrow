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
#   RubyChildInitHandler "Arrow::load_dispatchers('/Library/WebServer/arrow-hosts.yml')"
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
require 'arrow/factories'
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
	### files. See the ::instance method for more about how to use this method.
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

		# Set up global logging
		setup_logging()

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

		logfile = File::join( Dir::tmpdir, "arrow-fatal.log" )
		File::open( logfile, IO::WRONLY|IO::TRUNC|IO::CREAT ) {|ofh|
			ofh.puts( errmsg )
			ofh.flush
		}

		if defined?( Apache )
			Apache::request.server.log_crit( errmsg )
		end

		Kernel::raise( err )
	end


	### Get the instance of the Dispatcher set up under the given +key+, which
	### can either be a Symbol or a String containing the path to a
	### configfile. If no key is given, it defaults to :__default__, which is
	### the key assigned when ::create is given just a configfile argument.
	def self::instance( key=:__default__ )
		rval = nil

		# Fetch the instance which corresponds to the given key
		if key.is_a?( Symbol )
			Arrow::Logger.notice "Returning instance for key %p (one of %p): %p" %
				[key, @@Instance.keys, @@Instance[key]]
			rval = @@Instance[ key ]
		else
			Arrow::Logger.notice "Returning instance for configfile %p" % [key]
			configfile = File::expand_path( key )
			self.create( configfile )
			rval = @@Instance[ configfile ]
		end

		# Return either a configured Dispatcher instance or a FallbackHandler if
		# no Dispatcher corresponds to the given key.
		return rval || Arrow::FallbackHandler::new( key, @@Instance )
	end


	### Set up a global logger if one isn't already set up
	def self::setup_logging
		if Arrow::Logger::global.outputters.empty?
			outputter = Arrow::Logger::Outputter::create( 'apache' )
			Arrow::Logger::global.outputters << outputter
			Arrow::Logger::global.level = :notice
			Arrow::Logger[Arrow::Template].level = :notice
		end
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
			configfile = File::expand_path( configfile )
			if instances.key?( configfile )
				instances[ key ] = instances[ configfile ]
				next
			end

			# If a config file is given, load it. If it's not, just use the
			# default config.
			Arrow::Logger.notice "Arrow config file is %p" % configfile
			if configfile
				config = Arrow::Config::load( configfile )
			else
				config = Arrow::Config::new
			end

			# Create a dispatcher and put it in the table by both its key and
			# the normalized path to its configfile.
			instances[ key ] = instances[ configfile ] = new( config )
		end

		return instances
	end





	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Set up an Arrow::Dispatcher object based on the specified +config+
	### (an Arrow::Config object).
	def initialize( config )
		@config = config
		@broker = nil

		#if !Apache::Request::respond_to?( :libapreq? ) ||
		#		!Apache::Request::libapreq?
		#	raise "mod_ruby is not compiled with libapreq"
		#end

		self.configure( config )
	rescue ::Exception => err
		msg = "%s while creating dispatcher: %s\n%s" %
			[ err.class.name, err.message, err.backtrace.join("\n\t") ]
		self.log.error( msg )
		Apache::request.server.log_crit( msg ) unless !defined?( Apache )
	end


	######
	public
	######

	### (Re)configure the dispatcher based on the values in the given
	### +config+ (an Arrow::Config object).
	def configure( config )

		self.log.notice "Configuring a dispatcher for '%s' from '%s': child server %d" %
			[ Apache::request.server.hostname, config.name, Process::pid ]

		# Start the monitor backend if enabled
		if config.startMonitor?
			self.log.info "Starting Monitor backend"
			Arrow::Monitor::startBackend( config )
		else
			self.log.info "Monitor skipped by configuration"
		end

		# Set up the logging level
		self.log.info "Configuring log levels: %p" % config.logLevels
		config.logLevels.each do |klass, level|
			if klass == :global
				Arrow::Logger.global.level = level
				next
			end

			realclass = "Arrow::%s" % klass.to_s.
				sub(/^Arrow::/, '').
				sub(/^([a-z])/){ $1.upcase }
			Apache::request.server.log_notice(
				"Setting log level for %p to %p" % [realclass, level] )
			Arrow::Logger[ realclass ].level = level
		end
		
		Apache::request.server.log_notice( "Loggers: %p" % [Arrow::Logger.loggers] )

		# Set up the session class
		self.log.info "Configuring the Session class with %p" % config
		Arrow::Session::configure( config )

		# Create a new broker to handle applets
		self.log.info "Creating request broker"
		@broker = Arrow::Broker::new( config )
	end


	### mod_ruby Handlers

	### ChildInitHandler -- called once per child when it first starts up.
	def child_init( req )
		self.log.notice "Child #{Process::pid} starting up."

		# :TODO: Eventually provide hooks to applets so they can do slow startup
		# tasks.

		return Apache::OK
	end


	### The content handler method. Dispatches requests to registered
	### applets based on the requests PATH_INFO.
	def handler( req )
		self.log.debug "--- Dispatching request %p ---------------" % req

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
		self.log.debug "--- Done with request %p ---------------" % req

		return txn.status
	rescue ::Exception => err
		self.log.error "Transaction Manager Error: %s:\n\t%s" %
			[ err.message, err.backtrace.join("\n\t") ]
		return Apache::SERVER_ERROR
	end


	### Return a human-readable representation of the receiver as a String.
	def inspect
		return "#<%s:0x%x config: %s>" % [
			self.class.name,
			self.object_id,
			@config.name,
		]
	end



	#######
	private
	#######



end # class Arrow::Dispatcher

