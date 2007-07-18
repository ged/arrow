#!/usr/bin/env ruby
# 
# A convenience class for starting/stopping a non-forking apache server.
# 
# == Synopsis
# 
#   require 'tests/apacheserver'
#
#	# Create a new server instance
#	server = ApacheServer.new( :Listen => "localhost:4848" )
#
#	# Set some config values
#	server.config[:ErrorLog] = "myerrors"
#	server.config[:CustomLog] = %{"%h %l %u %t \"%r\" %>s %b" common}
#
#	# Start the server, execute the block, and then kill the server when the
#	# block's done.
#	server.start do 
#		...
#	end
#
#	# Just start the server again
#	server.start
#
#	# Move the filehandles open to the logs to the end
#	server.error_log.seek( 0, IO::SEEK_END )
#	server.access_log.seek( 0, IO::SEEK_END )
#
#	# Now kill the server
#	server.kill
# 
# == Authors
# 
# * Michael Granger <mgranger@RubyCrafters.com>
#
# Copyright (c) 2003 RubyCrafters, LLC. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# == Version
#
#  $Id$
# 

require 'apacheconfig'
require 'stringio'


### Class for controlling an apache server + configuration. Not to be confused
### with Apache::Server. =:)
class ApacheServer

	### Create a new ApacheServer object. If +config+ is not specified, the
	### default configuration is used.
	def initialize( config={} )
		unless config.is_a?( ApacheServer::Config )
			config = ApacheServer::Config.new( config )
		end
		
		@config = config
		@config_file = nil
		@exe = File.which( "httpd" )
		@pid = nil
		@errlog = nil
		@custom_logs = {}
	end


	######
	public
	######
	
	attr_reader :config, :config_file, :pid, :errlog, :custom_logs
	attr_accessor :exe, :root


	### Start the Apache server. If a block is specified, the server will be
	### started for the block, and then will be killed when the block is
	### complete.
	def start
		@config_file = @config.write

		# Open the error log and seek to the end so we can check for startup
		self.open_errlog
		self.open_custom_logs
		offset = @errlog.pos
	
		# Fork and send the child off to become the server		
		unless @pid = Kernel.fork
			begin
				self.start_httpd( @config_file )
			rescue Exception => e
				raise RuntimeError, "Child died before exec: %s:\n\t%s" %
					[ e.message, e.backtrace.join("\n\t") ]
			end
			exit
		end

		# Wait for the error log to say "resuming normal operations"
		waiting = true
		while waiting
			@errlog.seek( 0, IO::SEEK_CUR )
			
			# Stop waiting if the child dies for some reason
			deadpid, stat = Process.waitpid2( @pid, Process::WNOHANG )
			if stat
				$stderr.puts "waitpid returned non-nil: %d / %d, %s" %
					[ @pid, deadpid, stat.inspect ]
				break if deadpid == @pid
			end
			
			# Read the error log until something like "[Thu Apr 17 03:05:40
			# 2003] [notice] Apache/1.3.27 (Darwin) mod_ruby/1.1.1 configured --
			# resuming normal operations" is seen
			begin
				while line = @errlog.readline
					waiting = false if /resuming normal operations/ =~ line
				end
			rescue EOFError
				sleep 0.2
			end
		end

		raise RuntimeError, "Child server died during startup." unless
			waiting == false

		# Set the errorlog handle back to the place where the current server
		# started logging
		@errlog.seek( offset )

		# Set up a finalizer that will kill the child server/s if they are still
		# running.
		ObjectSpace.define_finalizer( self ) {
			begin
				Process.kill( "TERM", @pid )
				Process.wait
			rescue SystemCallError
			end
		}

		return @pid
	end


	### Returns +true+ if the server object has a slave httpd currently running.
	def running?
		return false if @pid.nil?

		if (Process.kill 0, @pid) == 1
			return true
		else
			return false
			end
	rescue Errno::ESRCH
		return false
	end


	### Sends the server a 'graceful' restart signal
	def graceful
		return nil unless self.running?
		Process.kill 'SIGUSR1', @pid
	end
	

	### Sends the server a hard restart signal
	def restart
		return nil unless self.running?
		Process.kill 'SIGHUP', @pid
	end
	
	
	### Stop the Apache server.
	def stop
		return nil unless self.running?
		begin
			Process.kill 'TERM', @pid
			Process.waitpid( @pid, 0 )
		rescue SystemCallError => err
			$stderr.puts "SystemCallError while stopping: #{err.message}" if
				$DEBUG || $VERBOSE
		end

		@errlog = nil
		@custom_logs = {}
		ObjectSpace.undefine_finalizer( self )	
	end		


	#########
	protected
	#########
	
	### Start the httpd as a child process and read its STDOUT and STDERR.
	def start_httpd( config_file )
		#$stderr.close
		#$stderr.reopen( $stdout )

		config_file = File.expand_path( config_file )

		command = [ @exe, '-F', '-f', config_file ]
		$stderr.puts "Starting server with: #{command.join(' ')}" if $DEBUG
		exec( *command )
	end

	### Open the file specified by the ErrorLog directive of the server's
	### configuration, seek to the end, and store the resulting filehandle in
	### @errlog.
	def open_errlog
		logfile = File.expand_path( @config[:ErrorLog], @config[:ServerRoot] )
		Dir.mkdir( File.dirname(logfile), 0755 ) if
			!File.directory?( File.dirname(logfile) )
		@errlog = File.open( logfile, File::RDONLY|File::CREAT )
		@errlog.seek( 0, IO::SEEK_END )
	end

	
	### Open any logs configured using the CustomLog directive of the server's
	### current configuration, seek to the end of each one, and store the resulting
	### IO objects as the values of a hash keyed by the logfile's pathname.
	def open_custom_logs
		logs = []
	
		# Depending on the format of the CustomLogs directive, build an array of
		# the filenames of logs to open.
		case @config[:CustomLog]
		when String
			logs.push File.expand_path( @config[:CustomLog].split(/\s+/, 2)[0],
										 @config[:ServerRoot] )

		when Hash
			logs.push @config[:CustomLog].collect {|logfile,format|
				File.expand_path( logfile, @config[:ServerRoot] )
			}
			
		when Array
			logs.push @config[:CustomLog].collect {|line|
				File.expand_path( line.split(/\s+/, 2)[0], @config[:ServerRoot] )
			}
		end

		# Now open each logfile and seek to the end
		logs.each {|logfile|
			Dir.mkdir( File.dirname(logfile), 0755 ) if
				!File.directory?( File.dirname(logfile) )
			@custom_logs[logfile] = File.open( logfile, File::RDONLY|File::CREAT )
			@custom_logs[logfile].seek( 0, IO::SEEK_END )
		}
	end

end


