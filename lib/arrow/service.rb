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
		'OPTIONS' => [ :options,    :options ],
		'GET'     => [ :fetch_all,  :fetch   ],
		'HEAD'    => [ :fetch_all,  :fetch   ],
		'POST'    => [ :create,     :create  ],
		'PUT'     => [ :update_all, :update  ],
		'DELETE'  => [ :delete_all, :delete  ],
	  }

	# Map of Ruby methods to their HTTP equivalents from either the single or collection URIs
	HTTP_METHOD_MAPPING = {
		:single => {
			:options    => 'OPTIONS',
			:fetch      => 'GET',
			:create     => 'POST',
			:update     => 'PUT',
			:delete     => 'DELETE',
		},
		:collection => {
			:options    => 'OPTIONS',
			:fetch_all  => 'GET',
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
		['application/json',           :to_json],
		['text/x-yaml',                :to_yaml],
		['application/xml+rubyobject', :to_xml],
		[RUBY_MARSHALLED_MIMETYPE,     :dump],
	]

	# The list of content-types and the corresponding method on the service to use to
	# transform it into something useful.
	DESERIALIZERS = {
		'application/json'                  => :deserialize_json_body,
		'text/x-yaml'                       => :deserialize_yaml_body,
		'application/x-www-form-urlencoded' => :deserialize_form_body,
		'multipart/form-data'               => :deserialize_form_body,
		RUBY_MARSHALLED_MIMETYPE            => :deserialize_marshalled_body,
	}


	# The content-type that's used for HTTP content negotiation if none
	# is set on the transaction
	DEFAULT_CONTENT_TYPE = RUBY_OBJECT_MIMETYPE

	# The key for POSTed/PUT JSON entity bodies that will be unwrapped as a simple string value.
	# This is necessary because JSON doesn't have a simple value type of its own, whereas all
	# the other serialization types do.
	SPECIAL_JSON_KEY = 'single_value'

	# Struct for containing thrown HTTP status responses
	StatusResponse = Struct.new( "ArrowServiceStatusResponse", :status, :message )


	######
	public
	######

	### OPTIONS /
	### Return a service document containing links to all 
	### :TODO: Integrate HTTP Access Control preflighted requests?
	###        (https://developer.mozilla.org/en/HTTP_access_control)
	def options( txn, *args )
		allowed_methods = self.allowed_methods( args )
		txn.headers_out['Allow'] = allowed_methods.join(', ')

		return allowed_methods
	end


	#########
	protected
	#########

	### Map the request in the given +txn+ to an action and return its name as a Symbol.
	def get_action_name( txn, id=nil, *args )
		http_method = txn.request_method
		self.log.debug "Looking up service action for %s %s (%p)" %
			[ http_method, txn.uri, args ]

		tuple = METHOD_MAPPING[ txn.request_method ] or return :not_allowed
		self.log.debug "Method mapping for %s is %p" % [ txn.request_method, tuple ]

		if args.empty?
			self.log.debug "  URI refers to top-level resource"
			msym = tuple[ id ? 1 : 0 ]
			self.log.debug "  picked the %p method (%s ID argument)" %
				[ msym, id ? 'has an' : 'no' ]

		else
			self.log.debug "  URI refers to a sub-resource (args = %p)" % [ args ]
			ops = args.collect {|arg| arg[/^([a-z]\w+)$/, 1].untaint }

			mname = "%s_%s" % [ tuple[1], ops.compact.join('_') ]
			msym = mname.to_sym
			self.log.debug "  picked the %p method (args = %p)" % [ msym, args ]
		end

		return msym, id, *args
	end


	### Given a +txn+, an +action+ name, and any other remaining URI path +args+ from 
	### the request, return a Method object that will handle the request (or at least something
	### #call-able with #arity).
	def find_action_method( txn, action, *args )
		return self.method( action ) if self.respond_to?( action )

		# Otherwise, return an appropriate error response
		self.log.error "request for unimplemented %p action for %s" % [ action, txn.uri ]
		return self.method( :not_allowed )
	end


	### Overridden to provide content-negotiation and error-handling.
	def call_action_method( txn, action, id=nil, *args )
		self.log.debug "calling %p( id: %p, args: %p ) for service request" %
			[ action, id, args ]
		content = nil

		# Run the action. If it executes normally, 'content' will contain the
		# object that should make up the response entity body. If :finish is
		# thrown early, e.g. via #finish_with, content will be nil and
		# http_status_response should contain a StatusResponse struct
		http_status_response = catch( :finish ) do
			if id
				id = self.validate_id( id )
				content = action.call( txn, id )
			else
				content = action.call( txn )
			end

			self.log.debug "  service finished successfully"
			nil # rvalue for catch
		end

		# Handle finishing with a status first
		if content
			txn.status ||= Apache::HTTP_OK
			return self.negotiate_content( txn, content )
		elsif http_status_response
			status_code = http_status_response[:status].to_i
			msg = http_status_response[:message]
			return self.prepare_status_response( txn, status_code, msg )
		end

		return nil
	rescue => err
		raise if err.class.name =~ /^Spec::/

		msg = "%s: %s %s" % [ err.class.name, err.message, err.backtrace.first ]
		self.log.error( msg )
		return self.prepare_status_response( txn, Apache::SERVER_ERROR, msg )
	end


	### Return a METHOD_NOT_ALLOWED response
	def not_allowed( txn, *args )
		txn.err_headers_out['Allow'] = self.build_allow_header( args )
		finish_with( Apache::METHOD_NOT_ALLOWED, "%s is not allowed" % [txn.request_method] )
	end


	### Return a valid 'Allow' header for the receiver for the given +path_components+ (relative to 
	### its mountpoint)
	def build_allow_header( path_components )
		return self.allowed_methods( path_components ).join(', ')
	end


	### Return an Array of valid HTTP methods for the given +path_components+
	def allowed_methods( path_components )
		type = path_components.empty? ? :collection : :single
		allowed = HTTP_METHOD_MAPPING[ type ].keys.
			find_all {|msym| self.respond_to?(msym) }.
			inject([]) {|ary,msym| ary << HTTP_METHOD_MAPPING[type][msym]; ary }

		allowed += ['HEAD'] if allowed.include?( 'GET' )
		return allowed.uniq.sort
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

		body = self.make_hypertext_from_content( content )

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


	### Make HTML from the given +content+, either via its #html_inspect method, or via
	### Arrow::HTMLUtilities.make_html_for_object if it doesn't respond to #html_inspect.
	def make_hypertext_from_content( content )
		if content.respond_to?( :html_inspect )
			self.log.debug "  making hypertext from %p using %p" %
				[ content, content.method(:html_inspect) ]
			body = content.html_inspect
		elsif content.respond_to?( :fetch ) && content.respond_to?( :collect )
			self.log.debug "  recursively hypertexting a collection"
			body = content.collect {|o| self.make_hypertext_from_content(o) }.join("\n")
		else
			self.log.debug "  using the generic HTML inspector"
			body = make_html_for_object( content )
		end

		return body
	end


	### Read the request body from the specified transaction, deserialize it if 
	### necessary, and return one or more Ruby objects. If there isn't a deserializer
	### in DESERIALIZERS that matches the request's `Content-type`, the request
	### is aborted with an "Unsupported Media Type" (415) response.
	def deserialize_request_body( txn )
		content_type = txn.headers_in['content-type'].sub( /;.*/, '' ).strip
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


	### Deserialize the given transaction's request body from an HTML form.
	def deserialize_form_body( txn )
		return txn.all_params
	end


	### Deserialize the given transaction's request body as JSON and return it.
	def deserialize_json_body( txn )
		rval = JSON.load( txn )
		if rval.is_a?( Hash ) && rval.keys == [ SPECIAL_JSON_KEY ]
			return rval[ SPECIAL_JSON_KEY ]
		else
			return rval
		end
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

