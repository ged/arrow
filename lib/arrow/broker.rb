#!/usr/bin/ruby
# 
# This file contains the Arrow::Broker class. The broker is the application
# manager. It maintains a registry of applications, and delegates transactions
# based on the request's URI.
# 
# == Rcsid
# 
# $Id: broker.rb,v 1.13 2004/01/26 05:46:12 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <mgranger@RubyCrafters.com>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file docs/COPYRIGHT for licensing details.
#

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/object'
require 'arrow/cache'
require 'arrow/factories'

module Arrow

	### Instance of this class contain a map of applications registered to a given location..
	class Broker < Arrow::Object

		### Class constants/methods

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.13 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: broker.rb,v 1.13 2004/01/26 05:46:12 deveiant Exp $

		# Registry entry data structure.
		RegistryEntry = Struct::new( :signature, :appclass, :object, :file, :timestamp )

		### Create a new Arrow::Broker object from the specified +config+ (an
		### Arrow::Config object).
		def initialize( config )
			@config				= config
			@templateFactory	= Arrow::TemplateFactory::new( config )
			@registry			= self.loadAppRegistry( config )
			@loadTime			= Time::now
		end


		######
		public
		######

		# The factory used to load/create/cache templates for applications
		attr_reader :templateFactory

		# The Hash of RegistryEntry structs which contain the actual
		# applications
		attr_reader :registry


		### Dispatch the specified transaction +txn+ to the appropriate handler
		### based on the request's path_info.
		def delegate( txn )
			pathInfo = txn.request.path_info.sub( %r{^/}, '' )
			self.log.debug "Request's path_info is %p" % pathInfo
			rval = appchain = nil

			# Check for updated/deleted/added apps
			self.checkForUpdates

			# Run either the default app if no path info was given, or an 
			if pathInfo.empty?
				rval = self.runDefaultApp( txn )
			else

				# Get the chain of apps to execute for the request
				appchain = self.findAppChain( pathInfo )

				# If the pathinfo doesn't correspond to at least one app, run
				# the no-such-app handler.
				if appchain.empty?
					rval = self.runNoSuchAppHandler( txn, pathInfo )
				else
					rval = self.runAppChain( txn, appchain )
				end
			end

			# Set the request status to declined if it hasn't been set yet and
			# the return value is false.
			if !rval && txn.status == Apache::OK
				self.log.error "Application returned false value. " +
					"Setting status to DECLINED"
				txn.status = Apache::DECLINED
			end

			# self.log.debug "Returning %p" % [ rval ]
			return rval
		end


		#########
		protected
		#########

		### Find the chain of applications indicated by the given +uriParts+ and
		### return an Array of tuples describing the chain. The format of the
		### chain will be:
		###   [ [RegistryEntry1, Array[*uriparts]], ... ]
		def findAppChain( uri, allowInternal=false )
			uriParts = uri.sub(%r{^/}, '').split(%r{/})
			appchain = []
			args = []

			self.log.debug "Search for appchain for %p" % [uriParts]
			if allowInternal
				identPat = /^\w[-\w]+/
			else
				identPat = /^[a-zA-Z][-\w]+/
			end

			# Map uri fragments onto registry entries
			uriParts.each_index {|i|
				unless identPat.match( uriParts[i] )
					self.log.debug "Stopping at %s: Not an identifier" %
						uriParts[i]
					break
				end

				newuri = uriParts[0,i+1].join("/")
				self.log.debug "Testing %s against %p" %
					[ newuri, @registry.keys.sort ]
				appchain << [@registry[newuri], uriParts[(i+1)..-1]] if
					@registry.key?( newuri )
			}

			#  Output the app chain to the debugging log.
			self.log.debug "Found %d apps in %p:\n\t%p" % [
				appchain.nitems,
				uriParts.join("/"),
				appchain.collect {|item|
					re = item[0]
					"%s (%s): %p" % [
						re.signature.name,
						re.object.class,
						item[1],
					]
				}.join("\n\t")
			]

			return appchain
		end


		### Given a chain of apps built from a URI, run the +index+th one with
		### the specified transaction (+txn+). Apps before the last get called
		### via their #delegate method, while the last one is called via #run.
		def runAppChain( txn, chain, index=0, *args )
			args.replace( chain[index][1] ) if args.empty?
			re = chain[index][0]
			txn.appPath = re.signature.uri

			# Run the final app in the chain
			if index == chain.nitems - 1
				self.log.debug "Running final app in chain"
				return self.runApp( re, txn, args )
			else
				self.log.debug "Running app %d in chain of %d" %
					[ index + 1, chain.nitems ]
				return re.object.delegate( txn, *args ) {|*args|
					self.runAppChain( txn, chain, index+1, *args )
				}
			end
		rescue ::Exception => err
			self.log.error "Error while executing app chain: %s (%s): %s:\n\t%s" % [
				re.signature.name,
				re.signature.uri,
				err.message,
				err.backtrace.join("\n\t"),
			]
			return self.runErrorHandler( re, txn, err )
		end


		### Run the application for the specified registry entry +re+ with the
		### given +txn+ (an Arrow::Transaction) and the +rest+ of the path_info
		### split on '/'.
		def runApp( re, txn, rest )
			self.log.debug "Running '%s' with args: %p" %
				[ re.signature.name, rest ]
			return re.object.run( txn, *rest )
		rescue ::Exception => err
			self.log.error "Error running %s (%s): %s:\n\t%s" % [
				re.signature.name,
				re.file,
				err.message,
				err.backtrace.join("\n\t"),
			]
			return self.runErrorHandler( re, txn, err )
		end


		### Handle requests that don't target a specific application (i.e.,
		### their path_info is empty). This will attempt to run whatever app is
		### configured as the default one (:defaultApp), or run a builtin status
		### app if no default is configured or if the configured one isn't
		### loaded.
		def runDefaultApp( txn, *args )
			rval = appchain = nil
			handlerUri = @config.defaultApp

			if handlerUri != "(builtin)"
				appchain = self.findAppChain( handlerUri, true )
				self.log.debug "Found appchain %p for default app" % [ appchain ]

				if appchain.empty?
					rval = self.runNoSuchAppHandler( txn, handlerUri )
				else
					rval = self.runAppChain( txn, appchain, 0, *args )
				end
			else
				rval = self.defaultDefaultHandler( txn )
			end

			return rval
		end


		### The builtin default handler routine. Outputs a plain-text status
		### message.
		def defaultDefaultHandler( txn )
			self.log.notice "Using builtin default handler."

			txn.request.content_type = "text/plain"
			return "Arrow Status: Running %s (%d apps loaded)" %
				[ Time::now, @registry.length ]
		end


		### Handle requests that target an application that doesn't exist.
		def runNoSuchAppHandler( txn, uri )
			rval = appchain = nil
			handlerUri = @config.noSuchAppHandler
			args = uri.split( %r{/} )

			# Build an app chain for user-configured handlers
			if handlerUri != "(builtin)"
				appchain = self.findAppChain( handlerUri, true )
				self.log.error "Configured NoSuchAppHandler (%s) doesn't exist" %
					handlerUri if appchain.empty?
			end

			# If the user-configured handler maps to one or more handlers, run
			# them. Otherwise, run the build-in handler.
			unless appchain.nil? || appchain.empty?
				rval = self.runAppChain( txn, appchain, 0, *args )
			else
				rval = self.defaultNoSuchAppHandler( txn, *args )
			end

			return rval
		end


		### The builtin no-such-app handler routine. Outputs a plain-text "no
		### such app" message.
		def defaultNoSuchAppHandler( txn, *args )
			self.log.notice "Using builtin no-such-app handler."
			return false
		end


		### Handle the given application error +err+ for the application
		### specified by the registry entry +re+, using the given transaction
		### +txn+. This will attempt to run whatever app is configured as the
		### error-handler, or run a builtin handler app if none is configured or
		### the configured one isn't loaded.
		def runErrorHandler( re, txn, err )
			rval = nil
			re ||= RegistryEntry::new
			handlerName = @config.errorHandler

			unless handlerName == "(builtin)" or !@registry.key?( handlerName )
				handler = @registry[handlerName]
				self.log.notice "Running error handler app '%s' (%s)" %
					[ handler.signature.name, handlerName ]

				begin
					rval = handler.object.run( txn, nil, re.signature.uri, re, err )
				rescue ::Exception => err2
					self.log.error "Error while attempting to use custom error "\
					"handler '%s': %s\n\t%s" % [
						handler.signature.name,
						err2.message,
						err2.backtrace.join("\n\t"),
					]

					rval = self.defaultErrorHandler( txn, re, err )
				end
			else
				rval = self.defaultErrorHandler( txn, re, err )
			end

			return rval
		end


		### The builtin error handler routine. Outputs a plain-text backtrace
		### for the given exception +err+ and registry entry +re+ to the given
		### transaction +txn+.
		def defaultErrorHandler( txn, re, err )
			self.log.notice "Using builtin error handler."
			txn.request.content_type = "text/plain"
			txn.status = Apache::OK

			return "Arrow Application Error in '%s': %s\n\t%s" %
				[ re.signature.name, err.message, err.backtrace.join("\n\t") ]
		end


		### Check the applications path for new/updated/deleted apps if the poll
		### interval has passed.
		def checkForUpdates
			return unless @config.applications.pollInterval.nonzero?
			if Time::now - @loadTime > @config.applications.pollInterval
				self.reloadAppRegistry( @config )
			end
		end


		### Find app files by looking in the applications path of the given
		### +config+ for files matching the configured pattern. Return an Array
		### of fully-qualified app files.
		def findAppFiles( config )
			files = []

			# For each directory in the configured applications path,
			# fully-qualify it and untaint the specified pathname.
			config.applications.path.each {|dir|
				next unless File::directory?( dir )

				pat = File::join( dir, config.applications.pattern )
				pat.untaint

				self.log.debug "Looking for applications: %p" % pat
				files.push( *Dir[ pat ] )
			}

			return files
		end


		### Load each file in the directories specified by the applications path
		### in the given config (an Arrow::Config object) into a Hash of
		### Arrow::Broker::RegistryEntry structs keyed by the path the
		### application responds to.
		def loadAppRegistry( config )
			self.log.debug "Loading app registry"
			registry = {}

			self.findAppFiles( config ).each do |appfile|
				self.log.debug "Found app file %p" % appfile
				appfile.untaint

				# Add each app object that successfully loads to the
				# registry under its uri.
				self.loadRegistryEntries( appfile ) {|re|
					uri = re.signature.uri

					# Handle URI collision
					if registry.key?( uri )
						msg = "URI collision for %s: %s vs. %s" %
							[ uri, re.file, registry[uri].file ]

						if @config.uriCollisionFatal
							raise Arrow::AppError, msg
						else
							self.log.warning msg
						end
					end

					self.log.info "Registered %s at '%s'" %
						[ re.appclass.name, uri ]
					registry[ re.signature.uri ] = re
				}
			end

			return registry
		end


		### Reload each file in the directories specified by the applications
		### path in the given config if it has been modified since it was last
		### loaded. Also check to see if there are any new files present, and if
		### so, load them.
		def reloadAppRegistry( config )

			checkedFiles = []

			# First compare the files corresponding to the loaded apps with
			# their files on disk, reloading if changed, removing if deleted,
			# etc.
			@registry.collect {|uri,re| [re.file, re.timestamp]}.uniq.each {|file, ts|

				# Delete registry entries for files that have been deleted.
				if !File::file?( file )
					@registry.delete_if {|uri,re| re.file == file}

				# Reload registry entries for files that have changed
				elsif File::mtime( file ) > ts
					self.loadRegistryEntries( file ) {|re|
						uri = re.signature.uri

						# Handle URI collision
						if registry.key?( uri ) && registry[uri].file != file
							msg = "URI collision for %s: %s vs. %s" %
								[ uri, re.file, registry[uri].file ]

							if @config.uriCollisionFatal
								raise Arrow::AppError, msg
							else
								self.log.warning msg
							end
						end
						
						self.log.info "Reloaded %s at '%s'" %
							[ re.appclass.name, uri ]
						@registry[ uri ] = re
					}

					# Delete any entries that were loaded from the old file
					@registry.delete_if {|uri, re|
						re.file == file && re.timestamp == ts
					}
				end

				checkedFiles << file
			}

			# Now check for new files, loading any that appear not to correspond
			# to any loaded app.
			appfiles = self.findAppFiles( config )
			(appfiles - ( appfiles & checkedFiles )).each {|appfile|
				appfile.untaint
				self.loadRegistryEntries( appfile ) {|re|
					uri = re.signature.uri

					# Handle URI collision
					if registry.key?( uri )
						msg = "URI collision for %s: %s vs. %s" %
							[ uri, re.file, registry[uri].file ]

						if @config.uriCollisionFatal
							raise Arrow::AppError, msg
						else
							self.log.warning msg
						end
					end

					self.log.info "Loaded new app %s at '%s'" %
						[ re.appclass.name, re.signature.uri ]
					@registry[ re.signature.uri ] = re
				}
			}
		end


		### Load the application classes from the given +appfile+ (a
		### fully-qualified pathname), and return a RegistryEntry instance for
		### each one.
		def loadRegistryEntries( appfile )
			self.log.debug "Attempting to load application objects from %p" % appfile
			entries = []
	
			# Get the application file's timestamp, load any application classes
			# in it, then make a registry entry for each one.
			timestamp = File::mtime( appfile )
			Arrow::Application::load( appfile ).each {|appclass|
				next unless appclass.signature? && appclass.signature.uri
				sig = appclass.signature
				obj = appclass.new( @config, @templateFactory )
				re = RegistryEntry::new( sig, appclass, obj, appfile, timestamp )

				self.log.debug "Created registry entry for %p (%s)" %
					[ obj, timestamp ]

				# Handle callback-style invocations
				if block_given?
					entries << yield( re )
				else
					entries << re
				end
			}

			self.log.info "Loaded %d entries." % entries.nitems
			return *entries
		rescue ::Exception => err
			self.log.error "%s failed to load: %s\n\t%s" %
				[ appfile, err.message, err.backtrace.join("\n\t") ]
		end


	end # class Broker

end # module Arrow


__END__


