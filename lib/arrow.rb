#!/usr/bin/env ruby
# 
# This file contains the Arrow module, a namespace container for classes in the
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
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#


require 'yaml'
require 'tmpdir'

require 'pathname'

### The module that serves as a namespace for all Arrow classes.
module Arrow

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	begin
		require 'arrow/constants'
		require 'arrow/monkeypatches'
		require 'arrow/applet'
		require 'arrow/dispatcher'
		require 'arrow/broker'
		require 'arrow/exceptions'
		require 'arrow/mixins'
	rescue LoadError
		if ! Object.constant_defined?( :Gem )
			require 'rubygems'
			retry
		end
		raise
	end

	# Hook up PluginFactory logging to Arrow logging
	PluginFactory.logger_callback = lambda do |lvl, msg|
		Arrow::Logger[PluginFactory].send( lvl, msg )
	end
	PluginFactory.log( :debug, "Hooked up PluginFactory logging through Arrow's logger." )

	### A +RubyChildInitHandler+ class which loads one or more dispatchers
	### when a child server starts. This can eliminate the startup lag for 
	### the first request each child handles. See the docs for dispatcher.rb 
	### for an example of how to use this.
	class DispatcherLoader
		
		### Create a loader that will create dispatchers from the given 
		### +hostsfile+, which is a YAML hash that maps dispatcher names to 
		### a configfile path. 
		def initialize( hostsfile )
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

end # module Arrow


