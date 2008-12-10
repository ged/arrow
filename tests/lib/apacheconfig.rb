#!/usr/bin/env ruby
# 
# The ApacheServer::Config -- a convenience class for writing
# Apache configuration files for the mod_ruby test suite.
# 
# == Synopsis
# 
#   require 'tests/lib/apacheconfig'
#	Config = ApacheServer::Config
#
#	# Create a new server instance
#	config = ApacheServer::Config.new( :Listen => "localhost:4848" )
#
#	# Set some config values
#	config[ :ErrorLog ] = "myerrors"
#	config[ :CustomLog ] = %{"%h %l %u %t \"%r\" %>s %b" common}
#
#	# Append mod_ruby to the list of loaded modules
#	config[ :LoadModule ] << "ruby_module mod_ruby.so"
#	config[ :AddModule ] << "mod_ruby.c"
#
#	# Add a Location section with a mod_ruby handler
#	config[ :RubyRequire ] ||= []
#	config[ :RubyRequire ] << "'simplehandler'"
# 	config[Config::Location.new("/test")] = {
# 		:SetHandler		=> "ruby-object",
# 		:RubyHandler	=> "SimpleHandler.instance",
# 	}
#
#	# Write the configuration to a file
#	config.write( "temp-httpd.conf" )
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
# == To Do
#
# * Turn this into a generally-useful class. This will require much
#   bullet-proofing, some changes to make it a more intuitive API, removal of
#   some shortcuts and assumptions being made about the environment it's running
#   in, and lots of documentation.
#
# == Version
#
#  $Id$
# 

require "filewhich"
begin
	require "stringio"
rescue LoadError
	eval %{class StringIO; end}
end

$isWindows = ! File::ALT_SEPARATOR.nil?

class ApacheServer

	### Configuration-generation class. It's fairly dumb at the moment -- it
	### doesn't actually know anything about the config file format, it just
	### knows how to write pairs and sections. It might be interesting to change
	### this in the future.
	class Config

		# Section classes
		class Section
			def initialize( arg ); @arg = arg; end
			attr_accessor :arg
			def name ; self.class.name.gsub(/.*::/, '') ; end
			def opentag ; "<%s %s>" % [ self.name, self.arg ] ; end
			def closetag ; "</%s>" % self.name ; end
		end

		class Directory < Section; end
		class DirectoryMatch < Section; end
		class Files < Section; end
		class FilesMatch < Section; end
		class IfDefine < Section; end
		class IfModule < Section; end
		class Limit < Section; end
		class LimitExcept < Section; end
		class Location < Section; end
		class LocationMatch < Section; end
		class VirtualHost < Section; end


		# Default config values: An array of two-element arrays which are used
		# with Array#assoc as a kind of ordered Hash.
		DefaultValues = [
			[:ResourceConfig,		$isWindows ? "nul" : "/dev/null"],
			[:AccessConfig,			$isWindows ? "nul" : "/dev/null"],

			[:ServerType,			"standalone"],

			# These two need full paths because of the way the server is
			# started. At least for now, anyway.
			[:ServerRoot,			File.expand_path("tests")],
			[:DocumentRoot,			File.expand_path("tests/docs")],

			[:PidFile,				"logs/test-httpd.pid"],
			[:ScoreBoardFile,		"logs/apache_runtime_status"],

			[:LoadModule, [
				"config_log_module libexec/mod_log_config.so",
				"mime_module libexec/mod_mime.so",
				"dir_module libexec/mod_dir.so",
				"cgi_module libexec/mod_cgi.so",
				"action_module libexec/mod_actions.so",
				"alias_module libexec/mod_alias.so",
				"access_module libexec/mod_access.so",
				"auth_module libexec/mod_auth.so",
			]],
					
			[:ClearModuleList,		nil],
			
			[:AddModule, [
				"mod_log_config.c",
				"mod_mime.c",
				"mod_dir.c",
				"mod_cgi.c",
				"mod_actions.c",
				"mod_alias.c",
				"mod_access.c",
				"mod_auth.c",
				"mod_so.c",
			]],

			[:Timeout,				300],
			[:KeepAlive,			true],
			[:MaxKeepAliveRequests,	100],
			[:KeepAliveTimeout,		15],

			[:Listen,				"127.0.0.1:8888"],

			[:UseCanonicalName,		true],
			[:ServerSignature,		false],
			[:HostnameLookups,		false],

			[:LogFormat,			%{"%h %l %u %t \\"%r\\" %>s %b" common}],
			[:LogFormat,			%{"%h %l %u %t \\"%r\\" %>s %b \\"%{Referer}i\\" \\"%{User-Agent}i\\"" combined}],
			[:CustomLog,			"logs/access_log combined"],
			[:ErrorLog,				"logs/error_log"],
			[:LogLevel,				"debug"],

			[Directory.new("/"), {
					:Options			=> "FollowSymLinks",
					:AllowOverride		=> "None",
			}],
			[Directory.new("/docs/"), {
					:Options			=> "All",
					:AllowOverride		=> "All",
			}]
		]
		DefaultValues.freeze

		### The default filename to write to
		DefaultFile = "httpd.conf.%d" % Process.pid


		### Create a new ApacheServer::Config object that will write to the
		### specified file with the given values.
		def initialize( values={} )
			@values = self.makeDeepCopy( DefaultValues )
			values.each {|pair| self[pair[0]] = pair[1] }
			# p @values
		end


		######
		public
		######

		### The internal hash of values
		attr_reader :values


		### Index operator. Retrieve the value/s associated with the specified
		### first instance of the specified key.
		def []( key )
			return @values.assoc(key)[1] if @values.assoc( key )
			return nil
		end
		
		
		### Index assignment operator.
		def []=( key, val )
			if @values.assoc( key )
				@values.assoc( key )[1] = val
			else
				self.append( key, val )
			end
		end


		### Append the given key/value pair to the configuration values in
		### the object.
		def append( key, val )
			@values << [ key, val ]
		end


		### Clear all values associated with the specified key in the
		### configuration.
		def clear( key=nil )
			if key.nil?
				@values.clear
			else
				newvals = []
				@values.delete_if {|pair| pair[0].hash == key.hash}
			end
		end


		### Write configuration values to the given file.
		def write( file=nil )
			file ||= File.join( self[:ServerRoot], DefaultFile )

			case file
			when IO, StringIO
				file.puts( self.to_s )
			when String
				File.open( file, File::CREAT|File::WRONLY|File::TRUNC ) {|ofh|
					ofh.puts( self.to_s )
				}
			else
				raise TypeError,
					"Bad argument: expected a String or an IO; got a %s" %
					file.class.name
			end

			return file
		end


		### Return the configuration as a single string
		def to_s
			string = <<-EOS.gsub(/^\t+/, '')
			### Apache config file -- auto-generated on #{Time.now.ctime}
			EOS

			@values.each do |pair|
				string << self.makeConfigPairString( *pair )
			end

			return string
		end


		#########
		protected
		#########

		### Given a source object +orig+, dup it and, in the case of Arrays and
		### Hashes, recurse over their contents and dup them, too.
		def makeDeepCopy( orig )
			# $stderr.puts "making a deep copy of #{orig.inspect}"
			case orig
			when Array
				dest = orig.collect {|elem| self.makeDeepCopy(elem)}
				# $stderr.puts "orig:#{orig.object_id} => dest:#{dest.object_id}"
				return dest
				
			when Hash
				dest = {}
				orig.each_pair {|k,v|
					key = self.makeDeepCopy(k)
					val = self.makeDeepCopy(v)
					dest[ key ] = val
				}
				# $stderr.puts "orig:#{orig.object_id} => dest:#{dest.object_id}"
				return dest

			# Can't dup these...
			when Symbol, NilClass, TrueClass, FalseClass, Numeric
				return orig
				
			else
				# $stderr.puts "Using the vanilla #dup"
				return orig.dup
			end
		end
		

		### Write a new section with the given +name+ and +values+ to the
		### specified output handle +ofh+. It will be indented by the given
		### +indent+.
		def makeSectionString( section, values, indent=0 )
			string = ""
			leading = " " * indent
			string << leading << section.opentag << "\n"
			values.each {|key,val|
				string << makeConfigPairString(key, val, indent+4)
			}
			string << leading << section.closetag << "\n\n"

			return string
		end


		### Return a configuration +key+/+val+ pair as a String, +indent+ed to
		### the specified level.
		def makeConfigPairString( key, val, indent=0 )
			string = ""

			case key
			when Symbol, String
				leading = " " * indent

				case val
				when nil
					string << leading + key.to_s + "\n"

				when String, Numeric
					string << leading + %{#{key.to_s} #{val.to_s}\n}

				when TrueClass
					string << leading + %{#{key.to_s} On\n}

				when FalseClass
					string << leading + %{#{key.to_s} Off\n}

				when Array
					string << val.collect {|v|
						leading + "#{key.to_s} #{v}"
					}.join("\n") << "\n"

				when Hash
					string << val.collect {|k,v|
						leading + "#{key.to_s} #{k.to_s} #{v}"
					}.join("\n") << "\n"

				else
					string << "# Error (unhandled config val type '%s'): %s" %
						[ val.class.name, val.inspect ]
				end

			when Section
				string << makeSectionString( key, val, indent )

			else
				raise TypeError, "Unhandled key-type: %s" % key.class.name
			end

			return string
		end
	end # class Config

end # class ApacheServer

