#!/usr/bin/ruby
# 
# This file contains the Arrow::Broker class. The broker is the applet
# manager. It maintains a registry of applets, and delegates transactions
# based on the request's URI.
# 
# == Subversion Id
#
#  $Id$
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

	### Instance of this class contain a map of applets registered to a given location..
	class Broker < Arrow::Object

		### Class constants/methods

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		# Registry entry data structure.
		RegistryEntry = Struct::new( :appletclass, :file, :timestamp, :object )


		### Create a new Arrow::Broker object from the specified +config+ (an
		### Arrow::Config object).
		def initialize( config )
			@config				= config
			@templateFactory	= Arrow::TemplateFactory::new( config )
			@registry			= self.loadAppletRegistry( config )
			@loadTime			= Time::now
		end


		######
		public
		######

		# The factory used to load/create/cache templates for applets
		attr_reader :templateFactory

		# The Hash of RegistryEntry structs which contain the actual
		# applets
		attr_reader :registry


		### Dispatch the specified transaction +txn+ to the appropriate handler
		### based on the request's path_info.
		def delegate( txn )
			pathInfo = txn.request.path_info.sub( %r{^/}, '' )
			self.log.debug "Request's path_info is %p" % pathInfo
			rval = appletchain = nil

			# Check for updated/deleted/added applets
			self.checkForUpdates

			# Run either the default applet if no path info was given, or an 
			if pathInfo.empty?
				rval = self.runDefaultApplet( txn )
			else

				# Get the chain of applets to execute for the request
				appletchain = self.findAppletChain( pathInfo )

				# If the pathinfo doesn't correspond to at least one applet, run
				# the no-such-applet handler.
				if appletchain.empty?
					rval = self.runNoSuchAppletHandler( txn, pathInfo )
				else
					rval = self.runAppletChain( txn, appletchain )
				end
			end

			# Set the request status to declined if it hasn't been set yet and
			# the return value is false.
			if !rval && txn.status == Apache::OK
				self.log.error "Applet returned false value. " +
					"Setting status to DECLINED"
				txn.status = Apache::DECLINED
			end

			# self.log.debug "Returning %p" % [ rval ]
			return rval
		end


		#########
		protected
		#########

		### Find the chain of applets indicated by the given +uriParts+ and
		### return an Array of tuples describing the chain. The format of the
		### chain will be:
		###   [ [RegistryEntry1, Array[*uriparts]], ... ]
		def findAppletChain( uri, allowInternal=false )
			uriParts = uri.sub(%r{^/}, '').split(%r{/})
			appletchain = []
			args = []

			self.log.debug "Search for appletchain for %p" % [uriParts]
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
				appletchain << [@registry[newuri], uriParts[(i+1)..-1]] if
					@registry.key?( newuri )
			}

			#  Output the applet chain to the debugging log.
			self.log.debug "Found %d applets in %p:\n\t%p" % [
				appletchain.nitems,
				uriParts.join("/"),
				appletchain.collect {|item|
					re = item[0]
					"%s (%s): %p" % [
						re.signature.name,
						re.object.class,
						item[1],
					]
				}.join("\n\t")
			]

			return appletchain
		end


		### Given a chain of applets built from a URI, run the +index+th one with
		### the specified transaction (+txn+). Applets before the last get called
		### via their #delegate method, while the last one is called via #run.
		def runAppletChain( txn, chain, index=0, *args )
			args.replace( chain[index][1] ) if args.empty?
			re = chain[index][0]
			txn.appletPath = re.signature.uri

			# Run the final applet in the chain
			if index == chain.nitems - 1
				self.log.debug "Running final applet in chain"
				return self.runApplet( re, txn, args )
			else
				self.log.debug "Running applet %d in chain of %d" %
					[ index + 1, chain.nitems ]
				return re.object.delegate( txn, *args ) {|*args|
					self.runAppletChain( txn, chain, index+1, *args )
				}
			end
		rescue ::Exception => err
			self.log.error "Error while executing applet chain: %s (%s): %s:\n\t%s" % [
				re.signature.name,
				re.signature.uri,
				err.message,
				err.backtrace.join("\n\t"),
			]
			return self.runErrorHandler( re, txn, err )
		end


		### Run the applet for the specified registry entry +re+ with the
		### given +txn+ (an Arrow::Transaction) and the +rest+ of the path_info
		### split on '/'.
		def runApplet( re, txn, rest )
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


		### Handle requests that don't target a specific applet (i.e.,
		### their path_info is empty). This will attempt to run whatever applet is
		### configured as the default one (:defaultApplet), or run a builtin status
		### applet if no default is configured or if the configured one isn't
		### loaded.
		def runDefaultApplet( txn, *args )
			rval = appletchain = nil
			handlerUri = @config.defaultApplet

			if handlerUri != "(builtin)"
				appletchain = self.findAppletChain( handlerUri, true )
				self.log.debug "Found appletchain %p for default applet" % [ appletchain ]

				if appletchain.empty?
					rval = self.runNoSuchAppletHandler( txn, handlerUri )
				else
					rval = self.runAppletChain( txn, appletchain, 0, *args )
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
			return "Arrow Status: Running %s (%d applets loaded)" %
				[ Time::now, @registry.length ]
		end


		### Handle requests that target an applet that doesn't exist.
		def runNoSuchAppletHandler( txn, uri )
			rval = appletchain = nil
			handlerUri = @config.noSuchAppletHandler
			args = uri.split( %r{/} )

			# Build an applet chain for user-configured handlers
			if handlerUri != "(builtin)"
				appletchain = self.findAppletChain( handlerUri, true )
				self.log.error "Configured NoSuchAppletHandler (%s) doesn't exist" %
					handlerUri if appletchain.empty?
			end

			# If the user-configured handler maps to one or more handlers, run
			# them. Otherwise, run the build-in handler.
			unless appletchain.nil? || appletchain.empty?
				rval = self.runAppletChain( txn, appletchain, 0, *args )
			else
				rval = self.defaultNoSuchAppletHandler( txn, *args )
			end

			return rval
		end


		### The builtin no-such-applet handler routine. Outputs a plain-text "no
		### such applet" message.
		def defaultNoSuchAppletHandler( txn, *args )
			self.log.notice "Using builtin no-such-applet handler."
			return false
		end


		### Handle the given applet error +err+ for the applet
		### specified by the registry entry +re+, using the given transaction
		### +txn+. This will attempt to run whatever applet is configured as the
		### error-handler, or run a builtin handler applet if none is configured or
		### the configured one isn't loaded.
		def runErrorHandler( re, txn, err )
			rval = nil
			re ||= RegistryEntry::new
			handlerName = @config.errorHandler

			unless handlerName == "(builtin)" or !@registry.key?( handlerName )
				handler = @registry[handlerName]
				self.log.notice "Running error handler applet '%s' (%s)" %
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

			return "Arrow Applet Error in '%s': %s\n\t%s" %
				[ re.signature.name, err.message, err.backtrace.join("\n\t") ]
		end


		### Check the applets path for new/updated/deleted applets if the poll
		### interval has passed.
		def checkForUpdates
			return unless @config.applets.pollInterval.nonzero?
			if Time::now - @loadTime > @config.applets.pollInterval
				self.updateAppletRegistry( @config )
			end
		end


		### Find applet files by looking in the applets path of the given
		### +config+ for files matching the configured pattern. Return an Array
		### of fully-qualified applet files.
		def findAppletFiles( config )
			files = []

			# For each directory in the configured applets path,
			# fully-qualify it and untaint the specified pathname.
			config.applets.path.each {|dir|
				next unless File::directory?( dir )

				pat = File::join( dir, config.applets.pattern )
				pat.untaint

				self.log.debug "Looking for applets: %p" % pat
				files.push( *Dir[ pat ] )
			}

			return files
		end


		### Load each file in the directories specified by the applets path in
		### the given config (an Arrow::Config object) into a Hash of
		### Arrow::Broker::RegistryEntry structs keyed by the name of the applet
		### class.
		def loadAppletRegistry( config )
			self.log.debug "Loading applet registry"
			registry = {}
			urimap = Hash::new {|ary,k| ary[k] = []}

			# Invert the applet layout into Class => [ uris ] so as classes
			# load, we know where to put 'em.
			config.applets.layout.each do |uri, klassname|
				self.log.debug "Mapping %p to %p" % [ klassname, uri ]
				urimap[ klassname ] << uri
			end

			# Now search the applet path for applet files
			self.findAppletFiles( config ).each do |appletfile|
				self.log.debug "Found applet file %p" % appletfile
				appletfile.untaint

				# Load registry entries for each class contained in the applet
				# file
				timestamp = File::mtime( appletfile )
				self.loadAppletClasses( appletfile ) {|klass|
					klassname = klass.name.sub( /#<Module:0x\w+>::/, '' )
					self.log.debug "Looking for a mapped %p" % klassname

					if urimap.key?( klassname )
						self.log.info "Found one or more uris for '%s'" % klassname

						# Install a distinct instance of the applet at each uri
						# it's registered under.
						urimap[ klassname ].each do |uri|
							applet = klass.new( @config, @templateFactory )
							re = RegistryEntry::new( klass, appletfile, timestamp, applet )
							self.log.info "Registered %p (%s) at '%s'" %
								[ applet, klassname, uri ]

							registry[ uri ] = re
						end
					else
						self.log.info "No uri for '%s': Not instantiated" % klassname
					end
				}
			end

			return registry
		end


		### Check for updates for each file in the directories specified by the
		### applet path in the given config if it has been modified since it was
		### last loaded. Also check to see if there are any new files present,
		### and if so, load them.
		def updateAppletRegistry( config )
			checkedFiles = []

			# First compare the files corresponding to the loaded applets with
			# their files on disk, reloading if changed, removing if deleted,
			# etc.
			@registry.collect {|name,re| [re.file, re.timestamp]}.uniq.each {|file, ts|

				# Delete registry entries for files that have been deleted.
				if !File::file?( file )
					@registry.delete_if {|name,re| re.file == file}

				# Reload registry entries for files that have changed
				elsif File::mtime( file ) > ts
					self.loadRegistryEntries( file ) {|re|
						klassname = re.signature.uri

						# Handle URI collision
						if registry.key?( uri ) && registry[uri].file != file
							msg = "URI collision for %s: %s vs. %s" %
								[ uri, re.file, registry[uri].file ]

							if @config.uriCollisionFatal
								raise Arrow::AppletError, msg
							else
								self.log.warning msg
							end
						end
						
						self.log.info "Reloaded %s at '%s'" %
							[ re.appletclass.name, uri ]
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
			# to any loaded applet.
			appletfiles = self.findAppletFiles( config )
			(appletfiles - ( appletfiles & checkedFiles )).each {|appletfile|
				appletfile.untaint
				self.loadRegistryEntries( appletfile ) {|re|
					uri = re.signature.uri

					# Handle URI collision
					if registry.key?( uri )
						msg = "URI collision for %s: %s vs. %s" %
							[ uri, re.file, registry[uri].file ]

						if @config.uriCollisionFatal
							raise Arrow::AppletError, msg
						else
							self.log.warning msg
						end
					end

					self.log.info "Loaded new applet %s at '%s'" %
						[ re.appletclass.name, re.signature.uri ]
					@registry[ re.signature.uri ] = re
				}
			}
		end


		### Load the applet classes from the given +appletfile+ and return them
		### in an Array. If a block is given, then each loaded class is yielded
		### to the block in turn, and the return values are used in the Array
		### instead.
		def loadAppletClasses( appletfile )
			self.log.debug "Attempting to load applet objects from %p" % appletfile
			classes = []
	
			# Get the applet file's timestamp, load any applet classes in it,
			# then yield it to the block or stick it in a return Array.
			Arrow::Applet::load( appletfile ).each {|appletclass|
				# Handle callback-style invocations
				if block_given?
					classes << yield( appletclass )
				else
					classes << appletclass
				end
			}

			self.log.info "Loaded %d classes." % classes.nitems
			return *classes
		rescue ::Exception => err
			self.log.error "%s failed to load: %s\n\t%s" %
				[ appletfile, err.message, err.backtrace.join("\n\t") ]
		end


	end # class Broker

end # module Arrow


__END__


