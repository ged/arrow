#!/usr/bin/ruby
# 
# This file contains the Arrow::Session::Id class, a derivative of
# Arrow::Object. Instances of concrete derivatives of this class are used as
# session IDs in Arrow::Session objects.
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

require 'arrow/object'
require 'arrow/mixins'
require 'arrow/session'


### Session ID class for in Arrow::Session objects.
class Arrow::Session::Id < Arrow::Object
	include PluginFactory

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Returns the Array of directories to search for derivatives; part of
	### the PluginFactory interface.
	def self::derivativeDirs
		[ 'arrow/session', 'arrow/session/id' ]
	end


	### Create a new Arrow::Session::Id object for the given +request+ (an
	### Apache::Request) of the type specified by +uri+.
	def self::create( uri, request, idstring=nil )
		uri = Arrow::Session.parse_uri( uri ) if uri.is_a?( String )
		super( uri.scheme.dup, uri, request, idstring )
	end


	### Generate a new id string for the given +request+.
	def self::generate( uri, request )
		raise NotImplementedError, "%s does not implement #generate" %
			self.name
	end


	### Validate the given +idstring+, returning an untainted copy of it if
	### it's valid, or +nil+ if it's not.
	def self::validate( uri, idstring )
		raise NotImplementedError, "%s does not implement #validate" %
			self.name
	end



	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################
	
	### Create a new Arrow::Session::Id object. If the +idstring+ is given, it
	### will be used as the unique key for this session. If it is not
	### specified, a new one will be generated.
	def initialize( uri, request, idstring=nil )
		@new = true

		if idstring
			self.log.debug "Validating id %p" % [ idstring ]
			@str = self.class.validate( uri, idstring )
			self.log.debug "  validation %s" % [ @str ? "succeeded" : "failed" ]
			@new = false
		end
		
		@str ||= self.class.generate( uri, request )
		super()
	end


	######
	public
	######


	### Return the id as a String.
	def to_s
		return @str
	end


	### Returns +true+ if the id was generated for this request as opposed
	### to being fetched from a cookie or the URL.
	def new?
		@new ? true : false
	end

end # class Arrow::Session::Id

