#!/usr/bin/ruby
# 
# This file contains the Arrow::Transaction class, a derivative of
# Arrow::Object. Instances of this class encapsulate a transaction within a web
# application implemented using the Arrow application framework.
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

require 'forwardable'
require 'uri'

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/object'

### The transaction class for Arrow web applications.
class Arrow::Transaction < Arrow::Object
	extend Forwardable

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	HTMLDoc = <<-"EOF".gsub(/^\t/, '')
	<html>
	  <head><title>%d %s</title></head>
	  <body><h1>%s</h1><p>%s</p></body>
	</html>
	EOF

	# Status names
	StatusName = {
		300		=> "Multiple Choices",
		301		=> "Moved Permanently",
		302		=> "Found",
		303		=> "See Other",
		304		=> "Not Modified",
		305		=> "Use Proxy",
		307		=> "Temporary Redirect",
	}


	# Methods that the transaction delegates to the underlying request
	# object.
	if defined?( Apache ) && defined?( Apache::Request )
		DelegatedMethods = Apache::Request.instance_methods(false) - [
			"inspect", "to_s", "status"
		]
	end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Transaction object with the specified +request+
	### (an Apache::Request object), +config+ (an Arrow::Config object),
	### +broker+ object (an Arrow::Broker), and +session+ (Arrow::Session)
	### objects.
	def initialize( request, config, broker )
		@request		= request
		@config			= config
		@broker			= broker

		@serial			= make_transaction_serial( request )

		# Stuff that may be filled in later
		@session		= nil # Lazily-instantiated
		@applet_path	= nil # Added by the broker
		@templates		= nil # Filled in by the applet
		@vargs			= nil #          "
		@status			= Apache::OK
		@data			= {}

		super()
	end


	######
	public
	######

	# Set up some delegators if running inside Apache
	if defined?( Apache ) && defined?( Apache::Request )
		def_delegators :@request, *DelegatedMethods
	end


	# The Apache::Request that initiated this transaction
	attr_reader :request

	# The Arrow::Config object for the Arrow application that created this
	# transaction.
	attr_reader :config

	# The Arrow::Broker that is responsible for delegating the Transaction
	# to one or more Arrow::Applet objects.
	attr_reader :broker

	# The hash of templates used by the applet this transaction is
	# bound for.
	attr_accessor :templates # :nodoc:

	# The argument validator (a FormValidator object)
	attr_accessor :vargs

	# The applet portion of the path_info
	attr_accessor :applet_path

	# The transaction's unique id in the context of the system.
	attr_reader :serial

	# The Apache status code of the transaction (e.g., Apache::OK,
	# Apache::DECLINED, etc.)
	attr_accessor :status

	# User-data hash. Can be used to pass data between applets in a chain.
	attr_reader :data



	### Returns a human-readable String representation of the transaction,
	### suitable for debugging.
	def inspect
		"#<%s:0x%0x serial: %s; status: %d>" % [
			self.class.name,
			self.object_id * 2,
			@serial,
			@status,
		]
	end


	### Returns +true+ if a session has been created for the receiver.
	def session?
		@session ? true : false
	end


	### The session associated with the receiver (an Arrow::Session object).
	def session( config={} )
		@session ||= Arrow::Session.create( self, config )
	end


	### Return the portion of the request's URI that serves as the base URI for
	### the application. All self-referential URLs created by the application
	### should include this.
	def app_root
		uri = @request.uri
		uri.sub!( Regexp.new(@request.path_info), '' )
		uri.chomp!( "/" )
		uri = "/" + uri unless uri[0] == ?/ || uri.empty?
		return uri
	end
	alias_method :approot, :app_root


	### Returns a fully-qualified URI String to the current applet using the
	### request object's server name and port.
	def app_root_url
		return construct_url( self.app_root )
	end
	

	### Return an absolute uri that refers back to the applet the transaction is
	### being run in
	def applet
		return [ self.app_root, self.applet_path ].join("/")
	end
	deprecate_method :action, :applet


	### Returns a fully-qualified URI String to the current applet using the
	### request object's server name and port.
	def applet_url
		return construct_url( self.applet )
	end
	

	### If the referer was another applet under the same Arrow instance, return
	### the uri to it. If there was no 'Referer' header, or the referer wasn't
	### an applet under the same Arrow instance, returns +nil+.
	def referring_applet
		return nil unless self.referer
		uri = URI.parse( self.referer )
		path = uri.path or return nil
		rootRe = Regexp.new( self.app_root + "/" )

		return nil unless rootRe.match( path )
		subpath = path.
			sub( rootRe, '' ).
			split( %r{/} ).
			first

		return subpath
	end
    deprecate_method :referringApplet, :referring_applet

	### If the referer was another applet under the same Arrow instance, return
	### the name of the action that preceded the current one. If there was no
	### 'Referer' header, or the referer wasn't an applet under the same Arrow
	### instance, return +nil+.
	def referring_action
		return nil unless self.referer
		uri = URI.parse( self.referer )
		path = uri.path or return nil
		appletRe = Regexp.new( self.app_root + "/\\w+/" )

		return nil unless appletRe.match( path )
		subpath = path.
			sub( appletRe, '' ).
			split( %r{/} ).
			first

		return subpath
	end
	deprecate_method :referringAction, :referring_action


	#
	# Header convenience methods
	#

	### Fetch the client's IP, either from proxy headers or the connection's IP.
	def remote_ip
		return self.headers_in['X-Forwarded-For'] || self.connection.remote_ip
	end
	deprecate_method :remoteIp, :remote_ip


	### Get the request's referer, if any
	def referer
		return self.headers_in['Referer']
	end


	### Set the result's 'Content-Disposition' header to 'attachment' and set
	### the attachment's +filename+.
	def attachment=( filename )
		val = %q{attachment; filename="%s"} % [ filename ]
		self.headers_out['Content-Disposition'] = val
	end
	

	#
	# Redirection methods
	#

	### Return a minimal HTML doc for representing a given status_code
	def status_doc( status_code, uri=nil )
		body = ''
		if uri
			body = %q{<a href="%s">%s</a>} % [ uri, uri ]
		end

		#<head><title>%d %s</title></head>
		#<body><h1>%s</h1><p>%s</p></body>
		return HTMLDoc % [
			status_code,
			StatusName[status_code],
			StatusName[status_code],
			body
		]
	end
    deprecate_method :statusDoc, :status_doc


	### Set the necessary fields in the request to cause the response to be a
	### redirect to the given +url+ with the specified +status_code+ (302 by
	### default).
	def redirect( uri, status_code=Apache::REDIRECT )
		
		# 304 responses don't get a Location or a body
		return( self.not_modified ) if status_code == Apache::HTTP_NOT_MODIFIED
		
		self.log.debug "Redirecting to %s" % uri

		# Set the status and Location: header
		self.headers_out[ 'Location' ] = uri.to_s
		self.status = status_code

		# Return "a short hypertext note with a hyperlink to the new URI" (from
		# the RFC).
		return status_doc( status_code, uri.to_s )
	end


	### Set the necessary header to make the displayed page refresh to the
	### specified +url+ in the given number of +seconds+.
	def refresh( seconds, url=nil )
		seconds = Integer( seconds )
		url ||= self.construct_url( '' )
		if !URI.parse( url ).absolute?
			url = self.construct_url( url )
		end
		
		self.headers_out['Refresh'] = "%d;%s" % [seconds, url]
	end


	### Get the verson of Arrow currently running.
	def arrow_version
		return Arrow::VERSION
	end
	deprecate_method :arrowVersion, :arrow_version

    
    #######
    private
    #######

    ### Make a transaction serial for the given instance.
	def make_transaction_serial( request )
		"%0.3f:%d:%s" % [
			Time.now.to_f,
			Process.pid,
			request.hostname,
		]
	end
    

end # class Arrow::Transaction


