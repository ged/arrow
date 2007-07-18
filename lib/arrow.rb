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

begin
	require 'rubygems'
rescue LoadError
	# No RubyGems is okay
end


### The module that serves as a namespace for all Arrow classes.
module Arrow

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Release version
	VERSION = '0.9.1'

	HOSTS_CONFIG_LINE = <<-EOF
	Can't load Arrow: No host config specified. Try setting the 'hosts_map' 
	option via a line like:
	
	  RubyOption hosts_map "/path/to/yaml/hosts/file.yml"
	EOF
	HOSTS_CONFIG_LINE.strip!

	# Yaml stuff
	YamlDomain = "rubycrafters.com,2003-10-22"

	require 'arrow/applet'
	require 'arrow/dispatcher'
	require 'arrow/broker'
	require 'arrow/exceptions'
	require 'arrow/mixins'


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
				self.name,
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


