#!/usr/bin/ruby
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


### The module that serves as a namespace for all Arrow classes.
module Arrow

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Release version
	VERSION = '0.1.0'

	# Yaml stuff
	YamlDomain = "rubycrafters.com,2003-10-22"

	require 'arrow/applet'
	require 'arrow/dispatcher'
	require 'arrow/broker'
	require 'arrow/exceptions'
	require 'arrow/mixins'

	### Load one or more arrow configurations from a YAML file, which lists each
	### config file under the key which will be used to fetch the request
	### processor. This is meant to be done from the +RubyChildInitHandler+, and
	### can eliminate the startup lag for the first request each child
	### handles. See the docs for dispatcher.rb for an example of how to use
	### this.
	def self::load_dispatchers( hosts_file )
		hosts_file.untaint
		configs = YAML.load( File.read(hosts_file) )

		# Convert the keys to Symbols and the values to untainted Strings.
		configs.each do |key,config|
			sym = key.to_s.intern
			configs[ sym ] = configs.delete( key )
			configs[ sym ].untaint
		end

		$deferr.puts "Loading dispatchers from %p" % [configs]

		return Arrow::Dispatcher.create( configs )
	rescue ::Exception => err

		# Try to log fatal errors to both the Apache server log and a crashfile
		# before passing the exception along.
		errmsg = "%s failed to load dispatchers (%s): %s: %s" % [
			self.name,
			err.class.name,
			err.message,
			err.backtrace.join("\n  ")
		]

		logfile = File.join( Dir.tmpdir, 'arrow-dispatcher-failure.log' )
		File.open( logfile, IO::WRONLY|IO::TRUNC|IO::CREAT ) {|ofh|
			ofh.puts( errmsg )
			ofh.flush
		}
		Apache.request.server.log_crit( errmsg )
		Kernel.raise( err )
	end

end # module Arrow


