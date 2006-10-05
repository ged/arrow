#!/usr/bin/ruby
# 
# This file contains the Arrow::AppletRegistry class, a derivative of
# Arrow::Object. Instances of this class are responsible for loading and
# maintaining the collection of Arrow::Applets registered with an 
# Arrow::Broker.
# 
# == Rcsid
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'arrow/broker'
require 'forwardable'


### Instances of this class are responsible for maintaining the collection of
### Arrow::Applets in an application..
class Arrow::AppletRegistry < Arrow::Object
	extend Forwardable
	include Enumerable, Arrow::Loggable
	
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Link in an applet chain
	ChainLink = Struct.new( 'ArrowAppletChainLink', :applet, :path, :args )

	### Registry applet filemap data structure.
	class AppletFile < Arrow::Object
		
		DEFAULT_SOURCE_WINDOW_SIZE = 20
		
		### Create a new Arrow::AppletRegistry::AppletFile for the applet at
		### the given +path+.
		def initialize( path )
			@path = path
			@uris = []
			@appletclasses = nil
			@timestamp = File.mtime( path )
			@exception = nil
			@loadTime = Time.at( 0 )
		end

		
		######
		public
		######
		
		# The fully-qualified path to the applet file
		attr_reader :path
		
		# An Array of URIs that applets contained in this file are mapped to
		attr_reader :uris
		
		# A Time object representing the modification time of the file when it was loaded
		attr_reader :timestamp
		
		# The Exception object that was thrown when trying to load this file, if any
		attr_accessor :exception
		
		
		### Returns +true+ if this file loaded without error
		def loaded_okay?
			@exception.nil?
		end
		

		### Returns +true+ if the corresponding file has changed since it was loaded
		def has_changed?
			@timestamp != File.mtime( path )
		end


		### Returns an Array of Arrow::Applet classes loaded from this file, loading 
		### them if they haven't already been loaded.
		def appletclasses
			unless @appletclasses
				self.log.debug "Loading applet classes from #{@path}"
				@appletclasses = Arrow::Applet.load( @path )
			end
			
		rescue ::Exception => err
			@exception = err
			frames = self.filtered_backtrace
			self.log.error "%s failed to load: %s" % [ path, err.message ]
			self.log.debug "  " + frames.collect {|frame| "[%s]" % frame}.join("  ")
			@appletclasses = []
		ensure
			return @appletclasses
		end


		### Return the lines of the applet exception's backtrace up to the
		### first frame of the framework. Returns an empty Array if there is
		### no current exception.
		def filtered_backtrace
			return [] unless @exception

			filtered = []
			@exception.backtrace.each do |frame|
				break if frame.include?('lib/arrow/')
				filtered.push( frame )
			end

			return filtered
		end
		

		### Return the lines from the applet's source as an Array.
		def source_lines
			File.readlines( @path )
		end


		### Return +window_size+ lines of the source from the applet 
		### surrounding the specified +linenum+ as an Array of Hashes of the 
		### form:
		###   {
		###     :source  => <line of source code>,
		###     :linenum => <line number>,
		###     :target  => <true if this is the target line>
		###   }
		def source_window( linenum, window_size=DEFAULT_SOURCE_WINDOW_SIZE )
			linenum -= 1
			before_line = linenum - (window_size / 2)
			after_line = linenum + (window_size / 2.0).ceil

			before_line = 0 if before_line < 0
			
			self.log.debug "Reading lines %d-%d from %s for source window on line %d" %
				[ before_line, after_line, @path, linenum + 1 ]
			
			rval = []
			lines = self.source_lines[ before_line .. after_line ]
			lines.each_with_index do |line, i|
				rval << {
					:source  => line.chomp,
					:linenum => before_line + i + 1,
					:target  => (before_line + i) == linenum,
				}
			end
			
			return rval
		end
		
		
		### Return the line of the exception that occurred while loading the
		### applet, if any. If there was no exception, this method returns
		### +nil+.
		def exception_line
			return nil unless @exception
			targetline = nil
			line = nil
			
			# ScriptErrors have the target line in the message; everything else
			# is assumed to have it in the first line of the backtrace
			if @exception.is_a?( ScriptError )
				targetline = @exception.message
			else
				targetline = @exception.backtrace.first
			end

			# 
			if targetline =~ /.*:(\d+)(?::.*)?$/
				line = Integer( $1 )
			else
				raise "Couldn't parse exception backtrace '%s' for error line." %
					[ targetline ]
			end
			
			return line
		end
		
		
		### Return +window_size+ lines surrounding the line of the applet's
		### loading exception. If there was no loading exception, returns
		### an empty Array.
		def exception_source_window( window_size=DEFAULT_SOURCE_WINDOW_SIZE )
			return [] unless @exception
			return self.source_window( self.exception_line, window_size )
		end
		
	end


	# The stuff the registry needs:
	#
	# * Map of uri to applet object [maps incoming requests to applet/s]
	# * Map of file to uri/s [for deleting entries from map of uris when a file disappears]
	
	### Create a new Arrow::AppletRegistry object.
	def initialize( config )
		@config = config
	
		@classmap = nil
		@filemap = {}
		@urispace = {}
		@template_factory = Arrow::TemplateFactory.new( config )
		
		self.load_applets
		super()
	end
	
	### Copy initializer -- reload applets for cloned registries.
	def initialize_copy( other ) # :nodoc:
		@config = other.config.dup

		@classmap = nil
		@filemap = {}
		@urispace = {}
		@template_factory = Arrow::TemplateFactory.new( config )
		
		self.load_applets
		super
	end


	######
	public
	######

	# The internal hash of Entry objects, keyed by URI
	attr_reader :urispace
	
	# The internal hash of Entry objects keyed by the file they were loaded 
	# from
	attr_reader :filemap

	# The Arrow::Config object which specified the registry's behavior.
	attr_reader :config
	

	# Delegate hash-ish methods to the uri-keyed internal hash
	def_delegators :@urispace, :[], :[]=, :key?, :keys, :length, :each


	### Find the chain of applets indicated by the given +uri+ and return an
	### Array of tuples describing the chain. The format of each tuple will
	### be:
	###	  [ Arrow::Applet, "<applet_uri>", ["remaining", "uri", "path"] ]
	### For example, a URI of "/admin/create/job/1" which maps to an applet 
	### at "/admin", will return the chain:
	###	  [ #<AdminApplet:0x2c78cbc>, "/admin", ["create", "job", "1"] ]
	def find_applet_chain( uri, allow_internal=false )
		self.log.debug "Searching urispace %p for appletchain for %p" %
		 	[@urispace.keys.sort, uri]
		uri_parts = uri.sub(%r{^/(?=.)}, '').split(%r{/})
		appletchain = []
		args = []

		# If there's an applet installed at the base, prepend it to the
		# appletchain
		if @urispace.key?( "" )
			appletchain << ChainLink.new( @urispace[""], "", uri_parts )
			self.log.debug "Added base applet to chain."
		end

		# Only allow reference to internal handlers (handlers mapped to 
		# directories that start with '_') if allow_internal is set.
		self.log.debug "Split URI into parts: %p" % [uri_parts]
		if allow_internal
			ident_pat = /^\w[-\w]*/
		else
			ident_pat = /^[a-zA-Z][-\w]*/
		end

		# Map uri fragments onto registry entries, stopping at any element 
		# which isn't a valid Ruby identifier.
		uri_parts.each_index do |i|
			unless ident_pat.match( uri_parts[i] )
				self.log.debug "Stopping at %s: Not an identifier" % uri_parts[i]
				break
			end

			newuri = uri_parts[0,i+1].join("/")
			self.log.debug "Testing %s against %p" % [ newuri, @urispace.keys.sort ]
			appletchain << ChainLink.new( @urispace[newuri], newuri, uri_parts[(i+1)..-1] ) if
				@urispace.key?( newuri )
		end

		return appletchain
	end


	### Loading and reloading the applet registy uses the following strategy:
	###
	### 1. Find all files in the config.applets.path matching the
	###	   config.applets.pattern.
	### 2. Remove from the registry any loaded applets which correspond to
	###	   applet files which are no longer in that list.
	### 3. For files which do exist in the path which were already loaded,
	###	   reload applets for any whose timestamp has changed since the applets
	###	   were loaded.
	### 4. For new files, load the applets they contain.
	
	### Load any new applets in the registry's path, reload any previously-
	### loaded applets whose files have changed, and discard any applets whose
	### files have disappeared.
	def load_applets
		self.log.debug "Loading applet registry"

		@classmap = self.build_classmap
		filelist = self.find_appletfiles

		# Remove applet files which correspond to files that are no longer
		# in the list
		self.purge_deleted_applets( @filemap.keys - filelist ) unless 
			@filemap.empty?

		# Now search the applet path for applet files
		filelist.each do |appletfile|
			# self.log.debug "Found applet file %p" % appletfile
			self.load_applets_from_file( appletfile )
			#self.log.debug "After %s, registry has %d entries" %
			#	[ appletfile, @urispace.length ]
		end

		@loadTime = Time.now
	end
	alias_method :reload_applets, :load_applets


	### Check the applets path for new/updated/deleted applets if the poll
	### interval has passed.
	def check_for_updates
		interval = @config.applets.pollInterval
		if interval.nonzero?
			if Time.now - @loadTime > interval
				self.log.debug "Checking for applet updates: poll interval at %ds" % interval
				self.reload_applets
			end
		else
			self.log.debug "Dynamic applet reloading turned off, continuing"
		end
	end



	#########
	protected
	#########

	### Remove the applets that were loaded from the given +missing_files+ from
	### the registry.
	def purge_deleted_applets( *missing_files )

		# For each filename, find the applets which were loaded from it, 
		# map the name of each applet to a uri via the classmap, and delete
		# the entries by uri
		missing_files.flatten.each do |filename|
			self.log.info "Unregistering old applets from %p" % [ filename ]

			@filemap[ filename ].uris.each do |uri|
				self.log.debug "  Removing %p, registered at %p" % [ @urispace[uri], uri ]
				@urispace.delete( uri )
			end
			
			@filemap.delete( filename )
		end
	end


	### Load the applet classes from the given +path+ and return them
	### in an Array. If a block is given, then each loaded class is yielded
	### to the block in turn, and the return values are used in the Array
	### instead.
	def load_applets_from_file( path )

		# Reload mode -- don't do anything unless the file's been updated
		if @filemap.key?( path )
			if @filemap[ path ].has_changed?
				self.log.info "File %p has changed since loaded. Reloading." % [path]
				self.purge_deleted_applets( path )
			else
				#self.log.debug "File %p has not changed." % [path]
				return nil
			end
		end

		self.log.debug "Attempting to load applet objects from %p" % path
		@filemap[ path ] = AppletFile.new( path )
	
		@filemap[ path ].appletclasses.each do |appletclass|
			#self.log.debug "Registering applet class %s from %p" % [appletclass.name, path]
			begin
				uris = self.register_applet_class( appletclass )
				@filemap[ path ].uris << uris
			rescue ::Exception => err
				frames = filter_backtrace( err.backtrace )
				self.log.error "%s loaded, but failed to initialize: %s" % [
					appletclass.normalized_name,
					err.message,
				]
				self.log.debug "  " + frames.collect {|frame| "[%s]" % frame }.join("  ")
				@filemap[ path ].exception = err
			end
		end
			
	end


	### Register an instance of the given +klass+ with the broker if the 
	### classmap includes it, returning the URIs which were mapped to 
	### instances of the +klass+.
	def register_applet_class( klass )
		uris = []

		# Trim the Module serving as private namespace from the
		# class name
		appletname = klass.normalized_name
		self.log.debug "Registering %p applet as %p" % [ klass.name, appletname ]

		# Look for a uri corresponding to the loaded class, and instantiate it
		# if there is one.
		if @classmap.key?( appletname )
			self.log.debug "  Found one or more uris for '%s'" % appletname
			

			# Create a new instance of the applet for each uri it's
			# registered under, then wrap that in a RegistryEntry
			# and put it in the entries hash we'll return later.
			@classmap[ appletname ].each do |uri|
				@urispace[ uri ] = klass.new( @config, @template_factory, uri )
				uris << uri
			end
		else
			self.log.debug "No uri for '%s': Not instantiated" % appletname
		end
		
		return uris
	end


	### Make and return a Hash which inverts the registry's applet
	### layout into a map of class name to the URIs onto which instances of
	### them should be installed.
	def build_classmap
		classmap = Hash.new {|ary,k| ary[k] = []}

		# Invert the applet layout into Class => [ uris ] so as classes
		# load, we know where to put 'em.
		@config.applets.layout.each do |uri, klassname|
			uri = uri.to_s.sub( %r{^/}, '' )
			self.log.debug "Mapping %p to %p" % [ klassname, uri ]
			classmap[ klassname ] << uri
		end

		return classmap
	end


	### Find applet files by looking in the applets path of the registry's 
	### configuration for files matching the configured pattern. Return an 
	### Array of fully-qualified applet files. If the optional +excludeList+ 
	### is given, exclude any files specified from the return value.
	def find_appletfiles( excludeList=[] )
		files = []
		dirCount = 0

		# For each directory in the configured applets path,
		# fully-qualify it and untaint the specified pathname.
		@config.applets.path.each do |path|

			# Look for files under a directory
			if File.directory?( path )
				dirCount += 1
				pat = File.join( path, @config.applets.pattern )
				pat.untaint

				self.log.debug "Looking for applets: %p" % pat
				files.push( *Dir[ pat ] )
			elsif File.file?( path )
				files.push( path )
			end
		end

		self.log.info "Fetched %d applet file paths from %d directories (out of %d)" %
			[ files.nitems, dirCount, @config.applets.path.dirs.nitems ]

		files.each {|file| file.untaint }
		return files - excludeList
	end




	#######
	private
	#######

	### Return frames from the given +backtrace+ that didn't come from the
	### current file.
	def filter_backtrace( backtrace )
		filtered = []
		backtrace.each do |frame|
			break if frame.include?(__FILE__)
			filtered.push( frame )
		end

		return filtered
	end

end # class Arrow::AppletRegistry


