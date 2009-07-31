#!/usr/bin/env ruby

require 'benchmark'
require 'tmpdir'

require 'arrow/object'
require 'arrow/config'
require 'arrow/applet'
require 'arrow/transaction'
require 'arrow/broker'
require 'arrow/template'
require 'arrow/templatefactory'

require 'arrow/fallbackhandler'


# The Arrow::Dispatcher class -- the mod_ruby handler frontend for Arrow.
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
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#
class Arrow::Dispatcher < Arrow::Object


	#################################################################
	###	C L A S S   M E T H O D S
	#################################################################

	@@Instance = {}

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
			raise ArgumentError, "Invalid config hash %p" % [configspec]
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


	### Create one or more dispatchers from the specified +hosts_file+, which is
	### a YAML file that maps arrow configurations onto a symbol that can be
	### used to refer to it.
	def self::create_from_hosts_file( hosts_file )
		configs = nil

		if hosts_file.respond_to?( :read )
			configs = YAML.load( hosts_file.read ) 
		else
			hosts_file.untaint
			configs = YAML.load_file( hosts_file )
		end

		# Convert the keys to Symbols and the values to untainted Strings.
		configs.each do |key,config|
			sym = key.to_s.dup.untaint.to_sym
			configs[ sym ] = configs.delete( key )
			configs[ sym ].untaint
		end

		@@Instance = self.create_configured_dispatchers( configs )
		return @@Instance
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
			msg = "Creating dispatcher %p from %p" % [ key, configfile ]
			Apache.request.server.log_notice( msg ) if defined?( Apache )
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

		@broker = Arrow::Broker.new( config )
		self.configure( config )
	rescue ::Exception => err
		msg = "%s while creating dispatcher: %s\n%s" %
			[ err.class.name, err.message, err.backtrace.join("\n\t") ]
		self.log.error( msg )
		msg.gsub!( /%/, '%%' )
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
		self.log.info "--- Dispatching request %p ---------------" % [req]
		self.log.debug "Request headers are: %s" % [untable(req.headers_in)]

		if (( reason = @config.changed_reason ))
			self.log.notice "** Reloading configuration: #{reason} ***"
			@config.reload
			@broker = Arrow::Broker.new( @config )
			self.configure( @config )
		end

		if ! @broker
			self.log.error "Fatal: No broker."
			return Apache::SERVER_ERROR
		end

		txn = Arrow::Transaction.new( req, @config, @broker )

		self.log.debug "Delegating transaction %p" % [txn]
		unless output = @broker.delegate( txn )
			self.log.info "Declining transaction (Applets returned: %p)" % output
			return Apache::DECLINED
		end

		# If the transaction succeeded, set up the Apache::Request object, add
		# headers, add session state, etc. If it failed, log the failure and let
		# the status be returned as-is.
		response_body = nil
		self.log.debug "Transaction has status %d" % [txn.status]

		# Render the output before anything else, as there might be
		# session/header manipulation left to be done somewhere in the
		# render. If the response is true, the applets have handled output
		# themselves.
		if output && output != true
			rendertime = Benchmark.measure do
				response_body = output.to_s
			end
			self.log.debug "Output render time: %s" %
				rendertime.format( '%8.4us usr %8.4ys sys %8.4ts wall %8.4r' )
			req.headers_out['content-length'] = response_body.length.to_s unless
				req.headers_out['content-length']
		end

		# If the transaction has a session, save it
		txn.session.save if txn.session?

		# Add cookies to the response headers
		txn.add_cookie_headers

		self.log.debug "HTTP response status is: %d" % [txn.status]
		self.log.debug "Response headers were: %s" % [untable(req.headers_out)]
		txn.send_http_header
		txn.print( response_body ) if response_body

		self.log.info "--- Done with request %p (%s)---------------" % 
			[ req, req.status_line ]

		req.sync = true
		return txn.handler_status
	rescue ::Exception => err
		self.log.error "Dispatcher caught an unhandled %s: %s:\n\t%s" %
			[ err.class.name, err.message, err.backtrace.join("\n\t") ]
		return Apache::SERVER_ERROR

	ensure
		# Make sure session locks are released
		txn.session.finish if txn && txn.session?
	end


	### Return a human-readable representation of the receiver as a String.
	def inspect
		return "#<%s:0x%x config: %s>" % [
			self.class.name,
			self.object_id,
			@config.name,
		]
	end


	def untable( table )
		lines = []
		table.each do |k,v|
			lines << "%s: %s" % [ k, v ]
		end
		
		return lines.join( "; " )
	end

end # class Arrow::Dispatcher

