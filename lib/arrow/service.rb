#!/usr/bin/ruby

require 'yaml'
require 'json'

require 'arrow/applet'

#
# This file contains the Arrow::Service class, a derivative of
# Arrow::Applet that provides some conveniences for creating REST-style
# service applets.
#
# It provides:
#   * automatic content-type negotiation
#   * automatic API description-generation for service actions
#   * new action dispatch mechanism that takes the HTTP request method into account
#   * convenience functions for returning a non-OK HTTP status
#
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#
class Arrow::Service < Arrow::Applet
	include Arrow::Loggable


	# Subversion revision
	SVNRev = %q$Rev$

	# Subversion id
	SvnId  = %q$Id$

	# Map of HTTP methods to their Ruby equivalents as tuples of the form:
	#   [ :method_without_args, :method_with_args ]
	METHOD_MAPPING = {
		'GET'    => [ :fetch,  :fetch_all  ],
		'HEAD'   => [ :fetch,  :fetch_all  ],
		'POST'   => [ :create, :create     ],
		'PUT'    => [ :update, :update_all ],
		'DELETE' => [ :delete, :delete_all ],
	  }

	# Map of Ruby methods to their HTTP equivalents from either the single or collection URIs
	HTTP_METHOD_MAPPING = {
		:single => {
			:fetch      => 'GET, HEAD',
			:create     => 'POST',
			:update     => 'PUT',
			:delete     => 'DELETE',
		},
		:collection => {
			:fetch_all  => 'GET, HEAD',
			:create     => 'POST',
			:update_all => 'PUT',
			:delete_all => 'DELETE',
		},
	}

	# Struct for containing thrown HTTP status responses
	StatusResponse = Struct.new( "ArrowServiceStatusResponse", :status, :message )
	

	######
	public
	######

	### Overridden to provide content-negotiation and error-handling.
	def run( txn, *args )
		self.time_request do
			self.log.debug "Looking up service action for %s %s" % [ txn.request_method, txn.uri ]
			has_args = ! args.empty?
			action = self.lookup_action( txn, has_args )
			
			if has_args
				id = validate_id( args.shift )
				content = action.call( txn, id, *args )
			else
				content = action.call( txn )
			end
			
			return content
		end
	end


	### Serialize the given +content+ according to the content-negotiation
	### headers of the request in the given +txn+. 
	def serialize_content( content, txn, *args )
	end



	#########
	protected
	#########

	### Look up which service action should be invoked based on the HTTP
	### request method and the number of arguments.
	def lookup_action( txn, has_args=false )
		http_method = txn.request_method

		tuple = METHOD_MAPPING[ txn.request_method ]
		self.log.debug "Method mapping for %s is %p" % [ txn.request_method, tuple ]
		msym = tuple[ has_args ? 0 : 1 ] if tuple
		self.log.debug "  picked the %p method (%s arguments)" % [ msym, has_args ? 'with' : 'no' ]

		return self.method( msym ) if msym && self.respond_to?( msym )
		self.log.error "request for unimplemented %p action for %s" % [ msym, txn.uri ]
		return self.method( :not_allowed )
	end


	### Return a METHOD_NOT_ALLOWED response
	def not_allowed( txn, *args )
		allowed = nil

		# Pick the allowed methods based on whether the request was to the collection resource or a
        # single resource
		type = args.empty? ? :collection : :single
		allowed = HTTP_METHOD_MAPPING[ type ].keys.
			find_all {|msym| self.respond_to?(msym) }.
			inject([]) {|ary,msym| ary << HTTP_METHOD_MAPPING[type][msym]; ary }

		txn.err_headers_out[:allow] = allowed.uniq.sort.join(', ')
		finish_with( Apache::METHOD_NOT_ALLOWED, "%s is not allowed" % [txn.request_method] )
	end


	### Validates the given string as a non-negative integer, either
	### returning it after untainting it or aborting with BAD_REQUEST. Override this
	### in your service if your resource IDs aren't integers.
	def validate_id( id )
		self.log.debug "validating ID %p" % [ id ]
		finish_with Apache::BAD_REQUEST, "missing ID" if id.nil?
		finish_with Apache::BAD_REQUEST, "malformed or invalid ID: #{id}" unless
			id =~ /^\d+$/

		id.untaint
		return Integer( id )
	end


	#######
	private
	#######

	### Abort the current execution and return a response with the specified
	### http_status code immediately. The specified +message+ will be logged,
	### and will be included in any message that is returned as part of the
	### response.
	def finish_with( http_status, message, otherstuff={} )
		http_response = otherstuff.merge( :status => http_status, :message => message )
		throw :finish, http_response
	end


	### Deep untaint an object structure and return it.
	def untaint_values( obj )
		self.log.debug "Untainting a result %s" % [ obj.class.name ]
		return obj unless obj.tainted?
		newobj = nil
		
		case obj
		when Hash
			newobj = {}
			obj.each do |key,val|
				newobj[ key ] = untaint_values( val )
			end

		when Array
			# Arrow::Logger[ self ].debug "Untainting array %p" % val
			newobj = obj.collect {|v| v.dup.untaint}

		else
			# Arrow::Logger[ self ].debug "Untainting %p" % val
			newobj = obj.dup
			newobj.untaint
		end
		
		return newobj
	end

end # class Arrow::Service

