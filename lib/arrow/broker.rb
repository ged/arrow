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

		# Filemap entry data structure
		class FileMapEntry < Struct::new( :file, :timestamp )
			def initialize( *args )
				@uris = []
				@classes = []
				@exception = nil
				super
			end

			# URIs associated with a class loaded from this file
			attr_reader :uris

			# The classes loaded from this file
			attr_reader :classes

			# The exception raised when attempting to load the file, if any
			attr_accessor :exception
			alias_method :exception?, :exception
		end


		### Create a new Arrow::Broker object from the specified +config+ (an
		### Arrow::Config object).
		def initialize( config )
			@config				= config
			@templateFactory	= Arrow::TemplateFactory::new( config )
			@filemap			= {}
			@loadTime			= Time::now

			@registry = self.loadAppletRegistry( config )
		end


		######
		public
		######

		# The factory used to load/create/cache templates for applets
		attr_reader :templateFactory

		# The Hash of RegistryEntry structs keyed by uri
		attr_reader :registry

		# A hash, keyed by the filenames of all files examined the last time the
		# registry was built, with FileMapEntrys for values.
		attr_reader :filemap


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
					rval = self.runMissingAppletHandler( txn, pathInfo )
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

		### Find the chain of applets indicated by the given +uri+ and return an
		### Array of tuples describing the chain. The format of the chain will
		### be:
		###   [ [RegistryEntry, URI, Array[*uriparts]], ... ]
		def findAppletChain( uri, allowInternal=false )
			uriParts = uri.sub(%r{^/}, '').split(%r{/})
			appletchain = []
			args = []

			self.log.debug "Searching for appletchain for %p" % [uriParts]
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
				appletchain << [@registry[newuri], newuri, uriParts[(i+1)..-1]] if
					@registry.key?( newuri )
			}

			#  Output the applet chain to the debugging log.
			self.log.debug "Found %d applets in %p:\n\t%p" % [
				appletchain.nitems,
				uriParts.join("/"),
				appletchain.collect {|item|
					re = item[0]
					"%s (%s): '%s': %p" % [
						re.appletclass.signature.name,
						re.appletclass,
						item[1],
						item[2]
					]
				}.join("\n\t")
			]

			return appletchain
		end


		### Given a chain of applets built from a URI, run the +index+th one with
		### the specified transaction (+txn+). Applets before the last get called
		### via their #delegate method, while the last one is called via #run.
		def runAppletChain( txn, chain )
			self.log.debug "Running applet chain: #{chain.inspect}"
			raise AppletError, "Malformed applet chain" if
				chain.empty? || !chain.first.is_a?( Array )

			re, txn.appletPath, args = self.unwrapChainLink( chain.first )

			# Run the final applet in the chain
			if chain.nitems == 1
				self.log.debug "Running final applet in chain"
				return self.runApplet( re, txn, args )
			else
				dchain = chain[ 1..-1 ]
				self.log.debug "Running applet %s in chain of %d; chain = %p" %
					[ re.object.signature.name, chain.nitems, dchain ]
			
				return re.object.delegate( txn, dchain, *args ) {|subchain|
					subchain = dchain if subchain.nil?
					self.log.debug "Delegated call to appletchain %p" % [ subchain ]
					self.runAppletChain( txn, subchain )
				}
			end
		rescue ::Exception => err
			self.log.error "Error while executing applet chain: %p (%s): %s:\n\t%s" % [
				re,
				chain.first[1],
				err.message,
				err.backtrace.join("\n\t"),
			]
			return self.runErrorHandler( re, txn, err )
		end

		
		### Check the specified +link+ of an applet chain for sanity and return
		### its constituent bits for assignment. This is necessary to provide
		### sensible errors if a delegating app screws up a chain somehow.
		def unwrapChainLink( link )
			re = link[0] or raise AppletChainError, "Null registry entry"

			unless re.is_a?( RegistryEntry )
				emsg = "Registry entry is a %s: Expected a RegistryEntry" %
					re.class.name
				raise AppletChainError, emsg
			end
			
			path = link[1] or raise AppletChainError, "Null path"
			args = link[2] or raise AppletChainError, "Null argument list"
			unless args.is_a?( Array )
				emsg = "Argument list is a %s: expected an Array" %
					args.class.name
				raise AppletChainError, emsg
			end					

			return re, path, args
		end


		### Run the applet for the specified registry entry +re+ with the
		### given +txn+ (an Arrow::Transaction) and the +rest+ of the path_info
		### split on '/'.
		def runApplet( re, txn, rest )
			self.log.debug "Running '%s' with args: %p" %
				[ re.appletclass.signature.name, rest ]
			return re.object.run( txn, *rest )
		rescue ::Exception => err
			self.log.error "Error running %s (%s): %s:\n\t%s" % [
				re.appletclass.signature.name,
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
			handlerUri = @config.applets.defaultApplet

			if handlerUri != "(builtin)"
				appletchain = self.findAppletChain( handlerUri, true )
				self.log.debug "Found appletchain %p for default applet" % [ appletchain ]

				if appletchain.empty?
					rval = self.runMissingAppletHandler( txn, handlerUri )
				else
					rval = self.runAppletChain( txn, appletchain )
				end
			else
				rval = self.builtinDefaultHandler( txn )
			end

			return rval
		end


		### The builtin default handler routine. Outputs a plain-text status
		### message.
		def builtinDefaultHandler( txn )
			self.log.notice "Using builtin default handler."

			txn.request.content_type = "text/plain"
			return "Arrow Status: Running %s (%d applets loaded)" %
				[ Time::now, @registry.length ]
		end


		### Handle requests that target an applet that doesn't exist.
		def runMissingAppletHandler( txn, uri )
			rval = appletchain = nil
			handlerUri = @config.applets.missingApplet
			args = uri.split( %r{/} )

			# Build an applet chain for user-configured handlers
			if handlerUri != "(builtin)"
				appletchain = self.findAppletChain( handlerUri, true )
				self.log.error "Configured MissingApplet handler (%s) doesn't exist" %
					handlerUri if appletchain.empty?
			end

			# If the user-configured handler maps to one or more handlers, run
			# them. Otherwise, run the build-in handler.
			unless appletchain.nil? || appletchain.empty?
				rval = self.runAppletChain( txn, appletchain )
			else
				rval = self.builtinMissingHandler( txn, *args )
			end

			return rval
		end


		### The builtin missing-applet handler routine. Outputs a plain-text "no
		### such applet" message.
		def builtinMissingHandler( txn, *args )
			self.log.notice "Using builtin missing-applet handler."
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
			handlerName = @config.applets.errorApplet.sub( %r{^/}, '' )

			unless handlerName == "(builtin)" or !@registry.key?( handlerName )
				handler = @registry[handlerName]
				self.log.notice "Running error handler applet '%s' (%s)" %
					[ handler.appletclass.signature.name, handlerName ]

				begin
					rval = handler.object.run( txn, "report_error", re, err )
				rescue ::Exception => err2
					self.log.error "Error while attempting to use custom error "\
					"handler '%s': %s\n\t%s" % [
						handler.appletclass.signature.name,
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
				[ re.appletclass.signature.name, err.message, err.backtrace.join("\n\t") ]
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
		### of fully-qualified applet files. If the optional +excludeList+ is
		### given, exclude any files specified from the return value.
		def findAppletFiles( config, excludeList=[] )
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

			return files - excludeList
		end


		### Load each file in the directories specified by the applets path in
		### the given config (an Arrow::Config object) into a Hash of
		### Arrow::Broker::RegistryEntry structs keyed by the name of the applet
		### class.
		def loadAppletRegistry( config )
			self.log.debug "Loading applet registry"
			registry = {}

			# Reverse map the config's applet layout so we can tell which
			# classes map to where in the URL hierarchy.
			urimap = self.makeUriMap( config )
			self.log.debug "Urimap: %p" % urimap

			# Now search the applet path for applet files
			self.findAppletFiles( config ).each do |appletfile|
				self.log.debug "Found applet file %p" % appletfile

				registry.merge!( self.loadRegistryEntries(appletfile, urimap) )
				self.log.debug "After merging applets from %s, registry is: %p" %
					[ appletfile, registry ]
			end

			return registry
		end


		### Make and return a Hash which inverts the given +config+'s applet
		### layout into a map of class name to the URIs onto which instances of
		### them should be installed.
		def makeUriMap( config )
			urimap = Hash::new {|ary,k| ary[k] = []}

			# Invert the applet layout into Class => [ uris ] so as classes
			# load, we know where to put 'em.
			config.applets.layout.each do |uri, klassname|
				uri = uri.to_s.sub( %r{^/}, '' )
				self.log.debug "Mapping %p to %p" % [ klassname, uri ]
				urimap[ klassname ] << uri
			end

			return urimap
		end


		### Load registry entries from the specified +appletfile+ and return
		### them in a hash keyed by uri. Use the specified +urimap+ (like the
		### one returned by #makeUriMap) to decide where to install any classes
		### that are loaded.
		def loadRegistryEntries( appletfile, urimap )
			entries = {}

			appletfile.untaint
			timestamp = File::mtime( appletfile )
			@filemap[ appletfile ] = FileMapEntry::new( appletfile, timestamp )

			self.log.debug "Mapping classes from %s using map: %p" %
				[ appletfile, urimap ]

			# Load registry entries for each class contained in the applet
			# file
			begin
				self.loadAppletClasses( appletfile ) {|klass|
					klassname = klass.name.sub( /#<Module:0x\w+>::/, '' )
					@filemap[ appletfile ].classes << klass
					self.log.debug "Looking for a mapped %p" % klassname

					if urimap.key?( klassname )
						self.log.info "Found one or more uris for '%s'" % klassname

						# Install a distinct instance of the applet at each uri
						# it's registered under.
						urimap[ klassname ].each do |uri|
							applet = klass.new( @config, @templateFactory )
							timestamp = Time::now
							re = RegistryEntry::new( klass, appletfile, timestamp, applet )
							self.log.info "Registered %p (%s) at '%s'" %
								[ applet, klassname, uri ]

							@filemap[ appletfile ].uris << uri
							entries[ uri ] = re
						end
					else
						self.log.info "No uri for '%s': Not instantiated" % klassname
					end
				}
			rescue ::Exception => err
				self.log.error "%s failed to load: %s\n\t%s" %
					[ appletfile, err.message, err.backtrace.join("\n\t") ]
				@filemap[ appletfile ].exception = err
			end

			self.log.debug "Returning registry entries: %p" % entries
			return entries
		end


		### Using the specified registry, return a Hash of Arrays of uris keyed
		### by the name of the file from which the applet installed there was
		### loaded.
		def makeRegistryMap( registry=@registry )
			regmap = Hash::new {|hsh,key| hsh[key] = []}
			registry.each {|uri,re|
				regmap[ re.file ] << uri
			}

			return regmap
		end


		### Check for updates for each file in the directories specified by the
		### applet path in the given config if it has been modified since it was
		### last loaded. Also check to see if there are any new files present,
		### and if so, load them.
		def updateAppletRegistry( config )

			# Fetch the list of available applet files
			filelist = self.findAppletFiles( config )

			# Make a registry map
			regmap = self.makeRegistryMap( @registry )

			# Delete applets for files that are no longer in the list
			(@filemap.keys - filelist).each do |file|
				self.log.debug "File '#{file}' no longer exists."

				# If something from the file is in the registry, remove them.
				regmap[ file ].each {|uri|
					self.log.notice "Removing app at %s: source file %s deleted" %
						[ uri, file ]
					@registry.delete( uri )
				}

				regmap.delete( file )
				@filemap.delete( file )
			end

			# Now check the timestamps of already-seen files and reload those
			# that have changed.
			filelist.each do |file|
				file.untaint

				if @filemap.key?( file )
					next if File::mtime( file ) == @filemap[file].timestamp
					self.log.debug "File '#{file}' changed since last seen."

					# Remove the registry entries loaded from this file
					regmap[ file ].each {|uri|
						self.log.notice "Removing %s for update from %s" %
						[ uri, file ]
						@registry.delete( uri )
					}

				else
					self.log.notice "Found new applet file '#{file}'"
				end

				# We need the urimap, so make it if it isn't already
				urimap ||= self.makeUriMap( config )

				# Reload the file and install any registry entries which are
				# loaded from it
				@registry.merge!( self.loadRegistryEntries(file, urimap) )
			end

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
					self.log.info "Yielding %s to caller." % appletclass.name
					classes << yield( appletclass )
				else
					self.log.info "Loaded %s." % appletclass.name
					classes << appletclass
				end
			}

			return *classes
		end


	end # class Broker

end # module Arrow


__END__


