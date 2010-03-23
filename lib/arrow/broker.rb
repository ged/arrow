#!/usr/bin/env ruby

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/object'
require 'arrow/cache'
require 'arrow/templatefactory'
require 'arrow/appletregistry'


# The broker is the applet manager. It maintains a registry of applets, and delegates 
# transactions based on the request's URI.
# 
# == Authors
# 
# * Michael Granger <mgranger@RubyCrafters.com>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Broker < Arrow::Object

	### Class constants/methods

	# A regular expression that matches the file separator on this system
	FILE_SEPARATOR = Regexp.new( Regexp.compile(File::SEPARATOR) )


	### Create a new Arrow::Broker object from the specified +config+ (an
	### Arrow::Config object).
	def initialize( config )
		@config = config
		@registry = Arrow::AppletRegistry.new( config )
		@start_time = Time.now
	end


	######
	public
	######

	# The Hash of RegistryEntry structs keyed by uri
	attr_accessor :registry

	# The Time when the Broker was started
	attr_reader :start_time



	### Dispatch the specified transaction +txn+ to the appropriate handler
	### based on the request's path_info.
	def delegate( txn )
		rval = appletchain = nil
		self.log.debug "Start of delegation (%s)" % [ txn.unparsed_uri ]

		# Fetch the path and trim the leading '/'
		path = txn.path
		path.sub!( %r{^/}, '' )
		self.log.debug "Request's path is %p" % path

		# Check for updated/deleted/added applets
		@registry.check_for_updates

		# Get the chain of applets to execute for the request
		appletchain = @registry.find_applet_chain( path )

		# If the pathinfo doesn't correspond to at least one applet, run
		# the no-such-applet handler.
		if appletchain.empty?
			rval = self.run_missing_applet_handler( txn, path )
		else
			rval = self.run_applet_chain( txn, appletchain )
		end

		# Set the request status to declined if it hasn't been set yet and
		# the return value is false.
		if !rval
			self.log.error "Applet returned false value. " +
				"Setting status to DECLINED"
			txn.status = Apache::DECLINED
		end

		# self.log.debug "Returning %p" % [ rval ]
		return rval
	end


	### Run the specified +applet+ with the given +txn+ (an Arrow::Transaction) 
	### and the +rest+ of the path_info split on '/'.
	def run_applet( applet, txn, rest )
		self.log.debug "Running '%s' with args: %p" %
			[ applet.signature.name, rest ]
		return applet.run( txn, *rest )
	rescue ::Exception => err
		self.log.error "[%s]: Error running %s (%s): %s:\n\t%s" % [
		    txn.serial,
			applet.signature.name,
			applet.class.filename,
			err.message,
			err.backtrace.join("\n\t"),
		]
		return self.run_error_handler( applet, txn, err )
	end


	### Handle requests that target an applet that doesn't exist.
	def run_missing_applet_handler( txn, uri )
		rval = appletchain = nil
		handlerUri = @config.applets.missingApplet
		args = uri.split( %r{/} )

		# Build an applet chain for user-configured handlers
		if handlerUri != "(builtin)"
			appletchain = @registry.find_applet_chain( handlerUri )
			self.log.error "Configured MissingApplet handler (%s) doesn't exist" %
				handlerUri if appletchain.empty?
		end

		# If the user-configured handler maps to one or more handlers, run
		# them. Otherwise, run the build-in handler.
		unless appletchain.nil? || appletchain.empty?
			rval = self.run_applet_chain( txn, appletchain )
		else
			rval = self.builtin_missing_handler( txn, *args )
		end

		return rval
	end


	### Handle the given applet error +err+ for the specified +applet+, using 
	### the given transaction +txn+. This will attempt to run whatever applet 
	### is configured as the error-handler, or run a builtin handler applet 
	### if none is configured or the configured one isn't loaded.
	def run_error_handler( applet, txn, err )
		rval = nil
		handlerName = @config.applets.errorApplet.sub( %r{^/}, '' )

		unless handlerName == "(builtin)" or !@registry.key?( handlerName )
			handler = @registry[handlerName]
			self.log.notice "Running error handler applet '%s' (%s)" %
				[ handler.signature.name, handlerName ]

			begin
				rval = handler.run( txn, "report_error", applet, err )
			rescue ::Exception => err2
				self.log.error "Error while attempting to use custom error "\
				"handler '%s': %s\n\t%s" % [
					handler.signature.name,
					err2.message,
					err2.backtrace.join("\n\t"),
				]

				rval = self.builtin_error_handler( applet, txn, err )
			end
		else
			rval = self.builtin_error_handler( applet, txn, err )
		end

		return rval
	end


	#########
	protected
	#########

	### Given a chain of applets built from a URI, run the +index+th one with
	### the specified transaction (+txn+). Applets before the last get called
	### via their #delegate method, while the last one is called via #run.
	def run_applet_chain( txn, chain )
		self.log.debug "Running applet chain: #{chain.inspect}"
		raise Arrow::AppletError, "Malformed applet chain" if
			chain.empty? || !chain.first.respond_to?( :applet )

		res = nil
		applet, txn.applet_path, args = self.unwrap_chain_link( chain.first )

		# If there's only one item left, run it
		if chain.nitems == 1
			self.log.debug "Running final applet in chain"
			res = self.run_applet( applet, txn, args )

		# Otherwise, delegate the transaction to the next applet with the
		# remainder of the chain.
		else
			dchain = chain[ 1..-1 ]
			self.log.debug "Running applet %s in chain of %d; chain = %p" %
				[ applet.signature.name, chain.nitems, dchain ]

			begin
				res = applet.delegate( txn, dchain, *args ) do |subchain|
					subchain = dchain if subchain.nil?
					self.log.debug "Delegated call to appletchain %p" % [ subchain ]
					self.run_applet_chain( txn, subchain )
				end
			rescue ::Exception => err
				self.log.error "Error while executing applet chain: %p (/%s): %s:\n\t%s" % [
					applet,
					chain.first[1],
					err.message,
					err.backtrace.join("\n\t"),
				]
				res = self.run_error_handler( applet, txn, err )
			end
		end

		return res
	end


	### Check the specified +link+ of an applet chain for sanity and return
	### its constituent bits for assignment. This is necessary to provide
	### sensible errors if a delegating app screws up a chain somehow.
	def unwrap_chain_link( link )
		applet = link.applet or raise Arrow::AppletChainError, "Null applet"
		path = link.path or raise Arrow::AppletChainError, "Null path"
		args = link.args or raise Arrow::AppletChainError, "Null argument list"
		unless args.is_a?( Array )
			emsg = "Argument list is a %s: expected an Array" %
				args.class.name
			raise Arrow::AppletChainError, emsg
		end					

		return applet, path, args
	end


	### The builtin missing-applet handler routine. Returns +false+, which 
	### causes the dispatcher to decline the request.
	def builtin_missing_handler( txn, *args )
		self.log.notice "Using builtin missing-applet handler."
		return false
	end


	### The builtin error handler routine. Outputs a plain-text backtrace
	### for the given exception +err+ and +applet+ to the given
	### transaction +txn+.
	def builtin_error_handler( applet, txn, err )
		self.log.notice "Using builtin error handler."
		txn.request.content_type = "text/plain"
		txn.status = Apache::OK

		return "Arrow Applet Error in '%s': %s\n\t%s" %
			[ applet.class.signature.name, err.message, err.backtrace.join("\n\t") ]
	end



end # class Arrow::Broker


__END__


