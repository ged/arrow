#!/usr/bin/ruby

require 'yaml'
require 'json'

require 'arrow/applet'
require 'arrow/acceptparam'

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
	include Arrow::Loggable,
	        Arrow::HTMLUtilities,
	        Arrow::Constants

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

	# A registry of HTTP status codes that don't allow an entity body in the response.
	BODILESS_HTTP_RESPONSE_CODES = [
		Apache::HTTP_CONTINUE,
		Apache::HTTP_SWITCHING_PROTOCOLS,
		Apache::HTTP_PROCESSING,
		Apache::HTTP_NO_CONTENT,
		Apache::HTTP_RESET_CONTENT,
		Apache::HTTP_NOT_MODIFIED,
		Apache::HTTP_USE_PROXY,
	]
	
	# The list of content-types and the corresponding message to send to transform
	# a Ruby object to that content type, in order of preference. See #negotiate_content.
	SERIALIZERS = [
		['application/json', :to_json],
		['text/x-yaml',      :to_yaml],
		['text/xml',         :to_xml],
	]

	# The list of content-types and the corresponding method on the service to use to
	# transform it into something useful.
	DESERIALIZERS = {
		'application/json'        => :deserialize_json_body,
		'text/x-yaml'             => :deserialize_yaml_body,
		RUBY_MARSHALLED_MIMETYPE  => :deserialize_marshalled_body,
	}


	# The content-type that's used for HTTP content negotiation if none
	# is set on the transaction
	DEFAULT_CONTENT_TYPE = RUBY_OBJECT_MIMETYPE
	

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
			action = self.lookup_action_method( txn, has_args )
			content = nil
			
			# Run the action. If it executes normally, 'content' will contain the
			# object that should make up the response entity body. If :finish is
			# thrown early, e.g. via #finish_with, content will be nil and
			# http_status_response should contain a StatusResponse struct
			http_status_response = catch( :finish ) do
				if has_args
					id = self.validate_id( args.shift )
					content = action.call( txn, id, *args )
				else
					content = action.call( txn )
				end

				self.log.debug "  service finished successfully"
				nil # rvalue for catch
			end
			
			# Handle finishing with a status first
			if content
				txn.status = Apache::HTTP_OK
				return self.negotiate_content( txn, content )
			elsif http_status_response
				status_code = http_status_response[:status].to_i
				msg = http_status_response[:message]
				return self.prepare_status_response( txn, status_code, msg )
			end

			return nil
		end
	rescue => err
		raise if err.class.name =~ /^Spec::/
		
		msg = "%s: %s %s" % [ err.class.name, err.message, err.backtrace.first ]
		self.log.error( msg )
		return self.prepare_status_response( txn, Apache::SERVER_ERROR, msg )
	end



	#########
	protected
	#########

	### Format the given +content+ according to the content-negotiation
	### headers of the request in the given +txn+. 
	def negotiate_content( txn, content )
		current_type = txn.content_type

		# If the content is already in a form the client understands, just return it
		# TODO: q-value upgrades?
		if current_type && txn.accepts?( current_type )
			self.log.debug "  '%s' content already in acceptable form for '%s'" %
				[ current_type, txn.normalized_accept_string ]
			return content 
		else
			self.log.info "Negotiating a response which matches '%s' from a %p entity body" %
				[ txn.normalized_accept_string, current_type || content.class ]

			# See if SERIALIZERS has an available transform that the request
			# accepts and the content supports.
			SERIALIZERS.each do |type, msg|
				if txn.explicitly_accepts?( type ) && content.respond_to?( msg )
					self.log.debug "  using %p to serialize the content to %p" % [ msg, type ]
					serialized = content.send( msg )
					txn.content_type = type
					return serialized
				end
			end
			self.log.debug "  no matching serializers, trying a hypertext response"

			# If the client can accept HTML, try to make an HTML response from whatever we have.
			if txn.accepts_html?
				self.log.debug "  client accepts HTML"
				return prepare_hypertext_response( txn, content )
			end
		
			return prepare_status_response( txn, Apache::NOT_ACCEPTABLE, "" )
		end
	end


	### Set up the response in the specified +txn+ based on the specified +status_code+ 
	### and +message+.
	def prepare_status_response( txn, status_code, message )
		self.log.info "Non-OK response: %d (%s)" % [ status_code, message ]

		txn.status = status_code

		# Some status codes allow explanatory text to be returned; some forbid it.
		unless BODILESS_HTTP_RESPONSE_CODES.include?( status_code )
			txn.content_type = 'text/plain'
			return message.to_s
		end
		
		# For bodiless responses, just tell the dispatcher that we've handled 
		# everything.
		return true
	end


	### Convert the specified +content+ to HTML and return it wrapped in a minimal 
	### (X)HTML document. The +content+ will be transformed into an HTML fragment via
	### its #html_inspect method (if it has one), or via 
	### Arrow::HtmlInspectableObject#make_html_for_object
	def prepare_hypertext_response( txn, content )
		self.log.debug "Preparing a hypertext response out of %p" %
			[ txn.content_type || content.class ]
		body = nil
		
		if content.respond_to?( :html_inspect )
			self.log.debug "  using the object's own #html_inspect"
			body = content.html_inspect
		else
			self.log.debug "  using the generic HTML inspector"
			body = make_html_for_object( content )
		end
		
		# Generate an HTML response
		tmpl = self.load_template( :service )
		tmpl.body = body
		tmpl.txn = txn
		tmpl.applet = self
		
		txn.content_type = HTML_MIMETYPE
		# txn.content_encoding = 'utf8'
		
		return tmpl
	end
	
	template :service => 'service-response.tmpl'
	

	### Look up which service action should be invoked based on the HTTP
	### request method and the number of arguments.
	def lookup_action_method( txn, has_args=false )
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

		txn.err_headers_out['Allow'] = allowed.uniq.sort.join(', ')
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


	### Read the request body from the specified transaction, deserialize it if 
	### necessary, and return one or more Ruby objects. If there isn't a deserializer
	### in DESERIALIZERS that matches the request's `Content-type`, the request
	### is aborted with an "Unsupported Media Type" (415) response.
	def deserialize_request_body( txn )
		content_type = txn.headers_in['content-type']
		self.log.debug "Trying to deserialize a %p request body." % [ content_type ]

		mname = DESERIALIZERS[ content_type ]
		
		if mname && self.respond_to?( mname )
			self.log.debug "  calling deserializer: #%s" % [ mname ]
			return self.send( mname, txn ) 
		else
			self.log.error "  no support for %p requests: %s" % [
				content_type,
				mname ? "no implementation of the #{mname} method" : "unknown content-type"
			  ]
			finish_with( Apache::HTTP_UNSUPPORTED_MEDIA_TYPE,
				"don't know how to handle %p requests" % [content_type, txn.request_method] )
		end
	end
	
	
	### Deserialize the given transaction's request body as JSON and return it.
	def deserialize_json_body( txn )
		return JSON.load( txn )
	end
	

	### Deserialize the given transaction's request body as YAML and return it.
	def deserialize_yaml_body( txn )
		return YAML.load( txn )
	end
	

	### Deserialize the given transaction's request body as a marshalled Ruby 
	### object and return it.
	def deserialize_marshalled_body( txn )
		return Marshal.load( txn )
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

