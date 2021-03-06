#
# Apache constants for testing, since the Apache module is really only loaded 
# when mod_ruby.so is.
#

# :stopdoc:

require 'fileutils'
require 'uri'
require 'forwardable'
require 'tmpdir'

class Integer # :nodoc: all
	def of
		accum = []
		self.times do |i|
			accum << yield(i)
		end
		accum
	end
end

module Apache # :nodoc: all

	M_GET       = 0
	M_PUT       = 1
	M_POST      = 2
	M_DELETE    = 3
	M_CONNECT   = 4
	M_OPTIONS   = 5
	M_TRACE     = 6
	M_PATCH     = 7
	M_PROPFIND  = 8
	M_PROPPATCH = 9
	M_MKCOL     = 10
	M_COPY      = 11
	M_MOVE      = 12
	M_LOCK      = 13
	M_UNLOCK    = 14
	M_INVALID   = 26
	METHODS     = 64

	METHOD_NUMBERS_TO_NAMES = {
		M_CONNECT	=> 'CONNECT',
		M_COPY		=> 'COPY',
		M_DELETE	=> 'DELETE',
		M_GET		=> 'GET',
		M_INVALID	=> 'INVALID',
		M_LOCK		=> 'LOCK',
		M_MKCOL		=> 'MKCOL',
		M_MOVE		=> 'MOVE',
		M_OPTIONS	=> 'OPTIONS',
		M_PATCH		=> 'PATCH',
		M_POST		=> 'POST',
		M_PROPFIND	=> 'PROFIND',
		M_PROPPATCH => 'PROPATCH',
		M_PUT		=> 'PUT',
		M_TRACE		=> 'TRACE',
		M_UNLOCK	=> 'UNLOCK',
	}
	METHOD_NAMES_TO_NUMBERS = METHOD_NUMBERS_TO_NAMES.invert

	OPT_NONE      = 0
	OPT_INDEXES   = 1
	OPT_INCLUDES  = 2
	OPT_SYM_LINKS = 4
	OPT_EXECCGI   = 8
	OPT_ALL       = 15
	OPT_UNSET     = 16
	OPT_INCNOEXEC = 32
	OPT_SYM_OWNER = 64
	OPT_MULTI     = 128

	SATISFY_ALL    = 0
	SATISFY_ANY    = 1
	SATISFY_NOSPEC = 2

	REQUEST_NO_BODY         = 0
	REQUEST_CHUNKED_ERROR   = 1
	REQUEST_CHUNKED_DECHUNK = 2

	REMOTE_HOST       = 0
	REMOTE_NAME       = 1
	REMOTE_NOLOOKUP   = 2
	REMOTE_DOUBLE_REV = 3

	DONE     = -2
	DECLINED = -1
	OK       = 0

	HTTP_CONTINUE            = 100
	HTTP_SWITCHING_PROTOCOLS = 101
	HTTP_PROCESSING          = 102

	DOCUMENT_FOLLOWS       = 200
	HTTP_OK                = 200
	HTTP_CREATED           = 201
	HTTP_ACCEPTED          = 202
	HTTP_NON_AUTHORITATIVE = 203
	HTTP_NO_CONTENT        = 204
	HTTP_RESET_CONTENT     = 205
	HTTP_PARTIAL_CONTENT   = 206
	PARTIAL_CONTENT        = 206
	HTTP_MULTI_STATUS      = 207

	HTTP_MULTIPLE_CHOICES   = 300
	MULTIPLE_CHOICES        = 300
	HTTP_MOVED_PERMANENTLY  = 301
	MOVED                   = 301
	HTTP_MOVED_TEMPORARILY  = 302
	REDIRECT                = 302
	HTTP_SEE_OTHER          = 303
	HTTP_NOT_MODIFIED       = 304
	USE_LOCAL_COPY          = 304
	HTTP_USE_PROXY          = 305
	HTTP_TEMPORARY_REDIRECT = 307

	BAD_REQUEST                        = 400
	HTTP_BAD_REQUEST                   = 400
	AUTH_REQUIRED                      = 401
	HTTP_UNAUTHORIZED                  = 401
	HTTP_PAYMENT_REQUIRED              = 402
	FORBIDDEN                          = 403
	HTTP_FORBIDDEN                     = 403
	HTTP_NOT_FOUND                     = 404
	NOT_FOUND                          = 404
	HTTP_METHOD_NOT_ALLOWED            = 405
	METHOD_NOT_ALLOWED                 = 405
	HTTP_NOT_ACCEPTABLE                = 406
	NOT_ACCEPTABLE                     = 406
	HTTP_PROXY_AUTHENTICATION_REQUIRED = 407
	HTTP_REQUEST_TIME_OUT              = 408
	HTTP_CONFLICT                      = 409
	HTTP_GONE                          = 410
	HTTP_LENGTH_REQUIRED               = 411
	LENGTH_REQUIRED                    = 411
	HTTP_PRECONDITION_FAILED           = 412
	PRECONDITION_FAILED                = 412
	HTTP_REQUEST_ENTITY_TOO_LARGE      = 413
	HTTP_REQUEST_URI_TOO_LARGE         = 414
	HTTP_UNSUPPORTED_MEDIA_TYPE        = 415
	HTTP_RANGE_NOT_SATISFIABLE         = 416
	HTTP_EXPECTATION_FAILED            = 417
	HTTP_UNPROCESSABLE_ENTITY          = 422
	HTTP_LOCKED                        = 423
	HTTP_FAILED_DEPENDENCY             = 424

	HTTP_INTERNAL_SERVER_ERROR = 500
	SERVER_ERROR               = 500
	HTTP_NOT_IMPLEMENTED       = 501
	NOT_IMPLEMENTED            = 501
	BAD_GATEWAY                = 502
	HTTP_BAD_GATEWAY           = 502
	HTTP_SERVICE_UNAVAILABLE   = 503
	HTTP_GATEWAY_TIME_OUT      = 504
	HTTP_VERSION_NOT_SUPPORTED = 505
	HTTP_VARIANT_ALSO_VARIES   = 506
	VARIANT_ALSO_VARIES        = 506
	HTTP_INSUFFICIENT_STORAGE  = 507
	HTTP_NOT_EXTENDED          = 510



	# Simulate Apache::Table
	class Table
		extend Forwardable
		def initialize( hash={} )
			hash.each {|k,v| hash[k.downcase] = v}
			@hash = hash
		end

		def_delegators :@hash, :clear, :each, :each_key, :each_value

		def []( key )
			@hash[ key.downcase ]
		end
		alias_method :get, :[]

		def []=( key, val )
			@hash[ key.downcase ] = val
		end
		alias_method :set, :[]=

		def key?( key )
			@hash.key?( key.downcase )
		end

		def merge( key, val )
			key = key.downcase
			@hash[key] = [@hash[key]] unless @hash[key].is_a?( Array )
			@hash[key] << val
		end
	end


	### Dummy mod_ruby object base class
	class ModRubySimObject
		@derivatives = {}
		class << self
			attr_reader :derivatives
		end

		def self::inherited( mod )
			@derivatives[ mod ] = caller( 1 ).first.split(/:/)
			$stderr.puts "Registering simulated %s at %p" % 
				[ mod.name, @derivatives[mod] ] if $DEBUG
			super
		end


		#######
		private
		#######

		def generate_method( name, argcount )
			return %q{def %s( %s ); end} % [ name, argcount.of {|i| "arg#{i}"}.join(", ") ]
		end

		def install_method( file, line, code )
			$stderr.puts "Installing method at line %d in %s" % [ line, file ]
			lines = File.readlines( file )
			tmpfile = "#{file}.#{Process.pid}"
			File.open( tmpfile, File::WRONLY|File::CREAT|File::EXCL ) do |fh|
				fh.puts( lines[0 .. line - 1] )
				fh.puts( code )
				fh.puts( lines[line .. -1] )
			end

			FileUtils.mv( tmpfile, file )
		end


		### Handle missing methods by auto-generating method definitions
		def method_missing( sym, *args )
			if (( source = Apache::ModRubySimObject.derivatives[ self.class ] ))
				sourcefile = source[0]
				sourceline = Integer( source[1] )

				$stderr.puts "call to missing method %s" % [ sym ]

				code = generate_method( sym, args.length )
				install_method( sourcefile, sourceline, code )

				eval( code )
				self.__send__( sym, *args )
			else
				super
			end
		end

	end

	###############
	module_function
	###############

	# Add a token to Apache's version string.
	def add_version_component( *args )
	end

	# Change the server's current working directory to the directory part of the specified filename.
	def chdir_file( str )
		str = File.dirname( str ) if ! File.directory?( str )
		Dir.chdir( str )
	end

	# Returns the current Apache::Request object.
	def request
		Apache::Request.new
	end

	# Returns the server's root directory (ie., the one set by the ServerRoot directive).
	def server_root
		Dir.tmpdir
	end

	# Returns the server built date string.
	def server_built
		return "Mar 20 2006 14:30:49"
	end

	# Returns the server version string.
	def server_version
		return "Apache/2.2.0 (Unix) mod_ruby/1.2.5 Ruby/1.8.4(2005-12-24)"
	end

	# Decodes a URL-encoded string.
	def unescape_url( str )
		return URI.unescape( str )
	end


	# Apache::Request
	class Request < ModRubySimObject

		INSTANCE_METHODS = %w{
			<< add_cgi_vars add_common_vars all_params allow_options
            allow_overrides allowed allowed= args args= attributes auth_name
            auth_name= auth_type auth_type= binmode bytes_sent cache_resp
            cache_resp= cancel connection construct_url content_encoding
            content_encoding= content_languages content_languages=
            content_length content_type content_type= cookies cookies=
            custom_response default_charset default_type disable_uploads=
            disable_uploads? dispatch_handler dispatch_handler= eof eof?
            err_headers_out error_message escape_html exception filename
            filename= finfo get_basic_auth_pw get_client_block getc
            hard_timeout header_only? headers_in headers_out hostname
            initial? internal_redirect kill_timeout last log_reason
            lookup_file lookup_uri main main? method_number next
            note_auth_failure note_basic_auth_failure
            note_digest_auth_failure notes options output_buffer param
            params params_as_string paramtable parse path_info path_info=
            post_max post_max= prev print printf protocol proxy? proxy_pass?
            putc puts read register_cleanup remote_host remote_logname
            replace request_method request_time requires reset_timeout
            satisfies script_name script_path send_fd send_http_header
            sent_http_header? server server_name server_port setup_cgi_env
            setup_client_block should_client_block should_client_block?
            signature soft_timeout status status= status_line status_line=
            subprocess_env sync= sync_header sync_header= sync_output
            sync_output= temp_dir temp_dir= the_request unparsed_uri
            upload_hook upload_hook= upload_hook_data upload_hook_data=
            uploads uploads_disabled? uri uri= user user= write
		}

		def self::instance_methods( include_superclass=true )
			return INSTANCE_METHODS
		end


		def initialize( uri=nil )
			@uri = uri
			@server = nil
			@allowed = Apache::M_GET | Apache::M_POST
			@paramtable = {}
			@sync_header = false
			@content_type = 'text/html'
			@hostname = 'localhost'
			@path_info = ''
			@headers_in = Apache::Table.new
			@headers_out = Apache::Table.new
			@options = {}
			@uploads = {}
			@method_number = Apache::M_GET
			@connection = Apache::Connection.new
		end

		attr_writer :server
		attr_accessor :allowed, :sync_header, :content_type, :uri,
			:hostname, :paramtable, :cookies, :options, :uploads,
			:path_info, :headers_in, :headers_out, :method_number,
			:connection
		alias_method :params, :paramtable
		alias_method :unparsed_uri, :uri

		def paramtable=( hash )
			# :TODO: Munge the hash into an Apache::Table object
			@paramtable = @params = hash.stringify_keys
		end
		alias_method :params=, :paramtable=

		def param( key )
			@paramtable[ key ]
		end

		def cookies=( hash )
			# :TODO: Munge the hash into a hash of Apache::Cookie objects
			@cookies = hash
		end

		def server
			@server ||= Apache::Server.new
		end

		def request_method
			return Apache::METHOD_NUMBERS_TO_NAMES[ @method_number ]
		end

		def request_method=( methodname )
			@method_number = Apache::METHOD_NAMES_TO_NUMBERS[ methodname ] or
				raise "No such HTTP method '%s'" % [methodname]
		end

		def remote_host( lookup=nil )
			return '127.0.0.1'
		end

		def the_request
			return 'GET / HTTP/1.1'
		end

		def status
			return Apache::OK
		end

	end

	class Server < ModRubySimObject
		def initialize
			@loglevel = 99 # No logging by default
		end

		attr_accessor :loglevel

		def hostname
			"localhost"
		end

		# Auto-generate log_* methods
		[
			:debug,
			:info,
			:notice,
			:warn,
			:error,
			:crit,
			:alert,
			:emerg,
		].each do |sym|
			define_method( "log_#{sym}" ) {|msg|
				$stderr.puts "#{sym.to_s.upcase}: #{msg}" if $DEBUG
			}
		end

		def admin
			"jrandomhacker@localhost"
		end
	end

	class Connection < ModRubySimObject
		def remote_host
			return '127.0.0.1'
		end
	end	  

	class Cookie < ModRubySimObject
	end	  

	class MultiVal < ModRubySimObject
	end	  

	class Upload < ModRubySimObject
	end	  

	class ParamTable < ModRubySimObject
	end

end

