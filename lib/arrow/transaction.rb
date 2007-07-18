#!/usr/bin/env ruby
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
require 'arrow/cookie'
require 'arrow/cookieset'


### The transaction class for Arrow web applications.
class Arrow::Transaction < Arrow::Object
	extend Forwardable

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	HTMLDoc = <<-"EOF".gsub(/^\t/, '')
	<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
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
	# object. If we're running inside mod_ruby, get the list from the class.
	if defined?( Apache ) && defined?( Apache::Request )
		DelegatedMethods = Apache::Request.instance_methods(false) - [
			"inspect", "to_s"
		]
		
	# Otherwise, just use the ones that were define when this was written (2007/03/20)
	else
		raise "No mod_ruby loaded. Try requiring 'apache/fakerequest' " +
			"to emulate the Apache environment."
	end


	#############################################################
	### I N S T A N C E	  M E T H O D S
	#############################################################

	### Create a new Arrow::Transaction object with the specified +request+
	### (an Apache::Request object), +config+ (an Arrow::Config object),
	### +broker+ object (an Arrow::Broker), and +session+ (Arrow::Session)
	### objects.
	def initialize( request, config, broker )
		@request			= request
		@config				= config
		@broker				= broker
		@handler_status     = Apache::OK

		@serial				= make_transaction_serial( request )

		# Stuff that may be filled in later
		@session			= nil # Lazily-instantiated
		@applet_path		= nil # Added by the broker
		@vargs				= nil # Filled in by the applet
		@data				= {}
		@request_cookies	= parse_cookies( request )
		@cookies			= Arrow::CookieSet.new()

		# Check for a "RubyOption root_dispatcher true"
		if @request.options.key?('root_dispatcher') &&
			@request.options['root_dispatcher'].match( /^(true|yes|1)$/i )
			self.log.debug "Dispatching from root path"
			@root_dispatcher = true
		else
			self.log.debug "Dispatching from sub-path"
			@root_dispatcher = false
		end

		super()
	end


	######
	public
	######

	# Set up some delegators if running inside Apache
	def_delegators :@request, *DelegatedMethods


	# The Apache::Request that initiated this transaction
	attr_reader :request

	# The Arrow::Config object for the Arrow application that created this
	# transaction.
	attr_reader :config

	# The Arrow::Broker that is responsible for delegating the Transaction
	# to one or more Arrow::Applet objects.
	attr_reader :broker

	# The argument validator (a FormValidator object)
	attr_accessor :vargs

	# The applet portion of the path_info
	attr_accessor :applet_path

	# The transaction's unique id in the context of the system.
	attr_reader :serial

	# User-data hash. Can be used to pass data between applets in a chain.
	attr_reader :data

	# The Hash of Arrow::Cookies parsed from the request
	attr_reader :request_cookies

	# The Arrow::CookieSet that contains cookies to be added to the response
	attr_reader :cookies

	# The handler status code to return to Apache
	attr_accessor :handler_status
	

	### Returns a human-readable String representation of the transaction,
	### suitable for debugging.
	def inspect
		"#<%s:0x%0x serial: %s; HTTP status: %d>" % [
			self.class.name,
			self.object_id * 2,
			self.serial,
			self.status
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


	### Returns true if the transactions response status is 2xx.
	def is_success?
		return nil unless self.status
		return (self.status / 100) == 2
	end
	

	### Returns true if the transaction's server status will cause the 
	### request to be declined (i.e., not handled by Arrow)
	def is_declined?
		self.log.debug "Checking to see if the transaction is declined (%p)" %
		 	[self.handler_status]
		return self.handler_status == Apache::DECLINED ? true : false
	end
	


	# Apache::Request attributes under various conditions. Need to determine 
	# if the dispatcher is mounted on the root URI without access to the 
	# config. It doesn't appear to be possible, since Apache doesn't set 
	# path_info for handlers mounted at "/":
	#
	# Dispatcher mounted on "/foo"											  
	# +--------------+-----------+-----------------+-------------+-------------+
	# | Request		 | path_info : unparsed_uri	   : uri		 : script_name :
	# +--------------+-----------+-----------------+-------------+-------------+
	# |/foo			 | ""		 | "/foo"		   | "/foo"		 | "/foo"	   |
	# |/foo/?a=b	 | "/"		 | "/foo/?a=b"	   | "/foo/"	 | "/foo"	   |
	# |/foo/args	 | "/args"	 | "/foo/args"	   | "/foo/args" | "/foo"	   |
	# |/foo/args?a=b | "/args"	 | "/foo/args?a=b" | "/foo/args" | "/foo"	   |
	# +--------------+-----------+-----------------+-------------+-------------+
	# Dispatcher mounted on "/":
	# +--------------+-----------+-----------------+-------------+-------------+
	# | Request		 | path_info : unparsed_uri	   : uri		 : script_name :
	# +--------------+-----------+-----------------+-------------+-------------+
	# | /			 | ""		 | "/"			   | "/"		 | "/"		   |
	# | /?a=b		 | ""		 | "/?a=b"		   | "/"		 | "/"		   |
	# | /args		 | ""		 | "/args"		   | "/args"	 | "/args"	   |
	# | /args?a=b	 | ""		 | "/args?a=b"	   | "/args"	 | "/args"	   |
	# +--------------+-----------+-----------------+-------------+-------------+
	# Note that with the dispatcher at "/", path_info is always empty and
	# #script_name is always the same as the #uri. Strange.

	### Returns +true+ if the dispatcher is mounted on the root URI ("/")
	def root_dispatcher?
		return @root_dispatcher
	end


	### Returns the path operated on by the Arrow::Broker when delegating the 
	### transaction. Equal to the #uri minus the #app_root.
	def path
		path = @request.uri
		uripat = Regexp.new( "^" + self.app_root )
		return path.sub( uripat, '' )
	end
	

	### Return the portion of the request's URI that serves as the base URI for
	### the application. All self-referential URLs created by the application
	### should include this.
	def app_root
		return "" if self.root_dispatcher?
		return @request.script_name
	end
	alias_method :approot, :app_root


	### Returns a fully-qualified URI String to the current applet using the
	### request object's server name and port.
	def app_root_url
		return construct_url( self.app_root )
	end
	alias_method :approot_url, :app_root_url
	

	### Return an absolute uri that refers back to the applet the transaction is
	### being run in
	def applet
		return [ self.app_root, self.applet_path ].join("/").gsub( %r{//+}, '/' )
	end
	deprecate_method :action, :applet
	alias_method :applet_uri, :applet


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

	### Add a 'Set-Cookie' header to the response for each cookie that
	### currently exists the transaction's cookieset.
	def add_cookie_headers
		self.cookies.each do |cookie|
			if self.is_success?
				self.log.debug "Adding 'Set-Cookie' header: %p (%p)" % 
					[cookie, cookie.to_s]
				self.headers_out['Set-Cookie'] = cookie.to_s
			else
				self.log.debug "Adding 'Set-Cookie' to the error headers: %p (%p)" %
					[cookie, cookie.to_s]
				self.err_headers_out['Set-Cookie'] = cookie.to_s
			end
		end
	end
	

	### :TODO: Need to override Apache::Request#construct_url to use Apache2's 
	### X-Forwarded-Host or X-Forwarded-Server when constructing 
	### self-refererential URLs.

	### Overridden from Apache::Request to take Apache mod_proxy headers into
	### account. If the 'X-Forwarded-Host' or 'X-Forwarded-Server' headers
	### exist in the request, the hostname specified is used instead of the
	### canonical host.
	def construct_url( uri )
		url = @request.construct_url( uri )

		# If the request came through a proxy, rewrite the url's host to match
		# the hostname the proxy is forwarding for.
		if (( host = self.proxied_host ))
			uriobj = URI.parse( url )
			uriobj.host = host
			url = uriobj.to_s
		end
		
		return url
	end


	### If the request came from a reverse proxy (i.e., the X-Forwarded-Host 
	### or X-Forwarded-Server headers are present), return the hostname that 
	### the proxy is forwarding for. If no proxy headers are present, return
	### nil.
	def proxied_host
		headers = @request.headers_in
		return headers['x-forwarded-host'] || headers['x-forwarded-server']
	end
	

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
		
		# IE flubs attachments of any mimetype it handles directly.
		if self.browser_is_ie?
			self.content_type = 'application/octet-stream'
		end
		
		val = %q{attachment; filename="%s"} % [ filename ]
		self.headers_out['Content-Disposition'] = val
	end


	### Return a URI object that is parsed from the request's URI.
	def parsed_uri
		return URI.parse( self.request.unparsed_uri )
	end
	
	
	### Return the Content-type header given in the request's headers, if any
	def request_content_type
		return self.headers_in['Content-type']
	end
	
	

	### Returns true if the User-Agent header indicates that the remote
	### browser is Internet Explorer. Useful for making the inevitable IE 
	### workarounds.
	def browser_is_ie?
		agent = self.headers_in['user-agent'] || ''
		return agent =~ /MSIE/ ? true : false
	end
	
	
	### Execute a block if the User-Agent header indicates that the remote
	### browser is Internet Explorer. Useful for making the inevitable IE 
	### workarounds.
	def for_ie_users
		yield if self.browser_is_ie?
	end


	### Return +true+ if the request is from XMLHttpRequest (as indicated by the
	### 'X-Requested-With' header from Scriptaculous or jQuery)
	def is_ajax_request?
		xrw_header = self.headers_in['x-requested-with']
		return true if !xrw_header.nil? && xrw_header =~ /xmlhttprequest/i
		return false
	end
	
	
	FORM_CONTENT_TYPES = %r{application/x-www-form-urlencoded|multipart/form-data}i
	
	### Return +true+ if there are HTML form parameters in the request, either in the
	### query string with a GET request, or in the body of a POST with a mimetype of 
	### either 'application/x-www-form-urlencoded' or 'multipart/form-data'.
	def form_request?
		case self.request_method
		when 'GET', 'HEAD'
			return (!self.parsed_uri.query.nil? || 
				self.request_content_type =~ FORM_CONTENT_TYPES) ? true : false
			
		when 'POST'
			return self.request_content_type =~ FORM_CONTENT_TYPES ? true : false
			
		else
			return false
		end
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
	def redirect( uri, status_code=Apache::HTTP_MOVED_TEMPORARILY )
		self.log.debug "Redirecting to %s" % uri
		self.headers_out[ 'Location' ] = uri.to_s
		self.status = status_code
		self.handler_status = Apache::REDIRECT

		return ''
	end


	### Set the necessary header fields in the response to cause a
	### NOT_MODIFIED response to be sent. 
	def not_modified
		return self.redirect( uri, Apache::HTTP_NOT_MODIFIED )
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


	### Parse cookies from the specified request and return them in a Hash.
	def parse_cookies( request )
		hash = Arrow::Cookie.parse(request.headers_in['cookie'])
		return Arrow::CookieSet.new( hash.values )
	end
	

end # class Arrow::Transaction

