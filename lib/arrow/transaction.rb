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

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/object'

module Arrow

### The transaction class for Arrow web applications.
class Transaction < Arrow::Object
	extend Forwardable

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Methods that the transaction delegates to the underlying request
	# object.
	if defined?( Apache ) && defined?( Apache::Request )
		DelegatedMethods = Apache::Request::instance_methods(false) - [
			"inspect", "to_s", "status"
		]
	end


	### Make a transaction serial for the given instance.
	def self::makeTransactionSerial( instance )
		"%0.3f:%d:%s" % [
			Time::now.to_f,
			Process::pid,
			instance.request.hostname,
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

		@serial			= self.class.makeTransactionSerial( self )

		# Stuff that may be filled in later
		@session		= nil # Lazily-instantiated
		@appletPath		= nil # Added by the broker
		@templates		= nil # Filled in by the applet
		@vargs			= nil #          "
		@status			= Apache::OK

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
	attr_accessor :templates

	# The argument validator (a FormValidator object)
	attr_accessor :vargs

	# The applet portion of the path_info
	attr_accessor :appletPath

	# The transaction's unique id in the context of the system.
	attr_reader :serial

	# The Apache status code of the transaction (e.g., Apache::OK,
	# Apache::DECLINED, etc.)
	attr_accessor :status


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
		@session ||= Arrow::Session::create( self, config )
	end


	### Return the portion of the request's URI that serves as the base URI for
	### the application. All self-referential URLs created by the application
	### should include this.
	def appRoot
		uri = @request.uri
		uri.sub!( Regexp::new(@request.path_info), '' )
		uri.chomp!( "/" )
		uri = "/" + uri unless uri[0] == ?/
		return uri
	end


	### Return an absolute uri that refers back to the applet the transaction is
	### being run in
	def action
		return [ self.appRoot, self.appletPath ].join("/")
	end


end # class Transaction
end # module Arrow


