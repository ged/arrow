#!/usr/bin/env ruby

require 'arrow'
require 'arrow/dispatcher'


### A +RubyChildInitHandler+ class which loads one or more dispatchers
### when a child server starts. This can eliminate the startup lag for 
### the first request each child handles. See the docs for dispatcher.rb 
### for an example of how to use this.
class Arrow::DispatcherLoader

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

end # class Arrow::DispatcherLoader

