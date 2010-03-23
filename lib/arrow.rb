#!/usr/bin/env ruby

require 'yaml'
require 'tmpdir'
require 'rubygems'

require 'pathname'


# 
# The Arrow module, a namespace container for classes in the
# Arrow web application framework.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Martin Chase <mchase@rubycrafters.com>
# * Michael Granger <mgranger@rubycrafters.com>
# * David McCorkhill <dmccorkhill@rubycrafters.com>
# 
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#
module Arrow

	# Library version
	VERSION = '1.0.6'


	# Try loading stuff through Rubygems if the require fails and Rubygems isn't loaded yet
	require 'arrow/constants'
	require 'arrow/monkeypatches'
	require 'arrow/exceptions'
	require 'arrow/mixins'
	require 'arrow/logger'


	# Hook up PluginFactory logging to Arrow logging
	PluginFactory.logger_callback = lambda do |lvl, msg|
		Arrow::Logger[PluginFactory].debug( msg )
	end
	PluginFactory.log.debug( "Hooked up PluginFactory logging through Arrow's logger." )


	### A +RubyChildInitHandler+ class which loads one or more dispatchers
	### when a child server starts. This can eliminate the startup lag for 
	### the first request each child handles. See the docs for dispatcher.rb 
	### for an example of how to use this.
	class DispatcherLoader

		### Create a loader that will create dispatchers from the given 
		### +hostsfile+, which is a YAML hash that maps dispatcher names to 
		### a configfile path. 
		def initialize( hostsfile )
			require 'arrow/applet'
			require 'arrow/dispatcher'
			require 'arrow/broker'

			@hostsfile = hostsfile
		end


		### Load the dispatchers according to the registered hosts file.
		def child_init( req )
			req.server.log_info( "Loading dispatcher configs from " + @hostsfile + "." )
			Arrow::Dispatcher.create_from_hosts_file( @hostsfile )

			return Apache::OK
		rescue ::Exception => err
			errmsg = "%s failed to load dispatchers (%s): %s: %s" % [
				self.class.name,
				err.class.name,
				err.message,
				err.backtrace.join("\n  ")
			]

			logfile = Pathname.new( Dir.tmpdir ) + 'arrow-dispatcher-failure.log'
			logfile.open( IO::WRONLY|IO::TRUNC|IO::CREAT ) do |ofh|
				ofh.puts( errmsg )
				ofh.flush
			end

			Apache.request.server.log_crit( errmsg )
			raise
		end

	end

	###############
	module_function
	###############

	### Search for and require ruby module files from subdirectories of the
	### $LOAD_PATH specified by +subdir+. If exclude_pattern is a Regexp or a
	### String, it will be used as a pattern to exclude matching module files.
	def require_all_from_path( subdir="arrow", exclude_pattern=nil )
		exclude_pattern = Regexp::compile( exclude_pattern.to_s ) unless
			exclude_pattern.nil? || exclude_pattern.is_a?( Regexp )

		subdir = Pathname.new( subdir ) unless subdir.is_a?( Pathname )

		$LOAD_PATH.
			collect {|dir| Pathname.new(dir) + subdir }.
			find_all {|dir| dir.directory? }.
			inject([]) {|files,dir|
				files += dir.entries.find_all {|file|
					/^[-.\w]+\.(rb|#{Config::CONFIG['DLEXT']})$/.match( file )
				}
			}.
			uniq.
			reject {|file| 
				exclude_pattern.match(file) unless exclude_pattern.nil?
			}.
			each do |file|
				require subdir + file
			end
	end

end # module Arrow
