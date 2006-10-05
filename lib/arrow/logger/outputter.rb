#!/usr/bin/ruby
# 
# This file contains the Arrow::Logger::Outputter class, which is the abstract
# base class for objects that control where logging output is sent in an
# Arrow::Logger object. 
# 
# == Subversion Id
#
#  $Id$
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

require 'pluginfactory'

require 'arrow/utils'
require 'arrow/exceptions'
require 'arrow/logger'
require 'arrow/mixins'

### This class is the abstract base class for logging outputters for
### Arrow::Logger.
class Arrow::Logger::Outputter
	include PluginFactory

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# The default description
	DefaultDescription = "Logging Outputter"

	# The default interpolatable string that's used to build the message to
	# output
	DefaultFormat =
		%q{#{time.strftime('%Y/%m/%d %H:%M:%S')} [#{level}]: #{name} } +
			%q{#{frame ? '('+frame+')' : ''}: #{msg[0,1024]}}


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Specify the directory to look for the derivatives of this class in.
	def self::derivativeDirs
		["arrow/logger"]
	end


	### Parse the given string into a URI object, appending the path part if
	### it doesn't exist.
	def self::parse_uri( str )
		return str if str.is_a?( URI::Generic )
		str += ":." if str.match( /^\w+$/ )
		URI.parse( str )
	end


	### Create a new Arrow::Logger::Outputter object of the type specified 
	### by +uri+.
	def self::create( uri, *args )
		uri = self.parse_uri( uri ) if uri.is_a?( String )
		super( uri.scheme.dup, uri, *args )
	end



	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Logger::Outputter object with the given +uri+,
	### +description+ and sprintf-style +format+.
	def initialize( uri, description=DefaultDescription, format=DefaultFormat )
		@description = description
		@format = format
	end


	######
	public
	######

	# The outputter's description, for introspection utilities.
	attr_accessor :description

	# The uninterpolated string format for this outputter. This message
	# written will be formed by interpolating this string in the #write
	# method's context immediately before outputting.
	attr_accessor :format


	### Write the given +level+, +name+, +frame+, and +msg+ to the target
	### output mechanism. Subclasses can call this with a block which will
	### be passed the formatted message. If no block is supplied by the
	### child, this method will check to see if $DEBUG is set, and if it is,
	### write the log message to $deferr.
	def write( time, level, name, frame, msg )
		msg = @format.interpolate( binding )

		if block_given?
			yield( msg )
		else
			$deferr.puts( msg ) if $DEBUG
		end
	end


end # class Arrow::Logger::Outputter


