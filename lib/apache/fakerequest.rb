#
# Apache constants for testing, since the Apache module is really only loaded 
# when mod_ruby.so is.
#

require 'fileutils'
require 'uri'

class Integer
	def of
		accum = []
		self.times do |i|
			accum << yield(i)
		end
		accum
	end
end

module Apache # :nodoc:
    AUTH_REQUIRED = 401
    BAD_GATEWAY = 502
    BAD_REQUEST = 400
    DECLINED = -1
    DOCUMENT_FOLLOWS = 200
    DONE = -2
    FORBIDDEN = 403
    HTTP_ACCEPTED = 202
    HTTP_BAD_GATEWAY = 502
    HTTP_BAD_REQUEST = 400
    HTTP_CONFLICT = 409
    HTTP_CONTINUE = 100
    HTTP_CREATED = 201
    HTTP_EXPECTATION_FAILED = 417
    HTTP_FAILED_DEPENDENCY = 424
    HTTP_FORBIDDEN = 403
    HTTP_GATEWAY_TIME_OUT = 504
    HTTP_GONE = 410
    HTTP_INSUFFICIENT_STORAGE = 507
    HTTP_INTERNAL_SERVER_ERROR = 500
    HTTP_LENGTH_REQUIRED = 411
    HTTP_LOCKED = 423
    HTTP_METHOD_NOT_ALLOWED = 405
    HTTP_MOVED_PERMANENTLY = 301
    HTTP_MOVED_TEMPORARILY = 302
    HTTP_MULTIPLE_CHOICES = 300
    HTTP_MULTI_STATUS = 207
    HTTP_NON_AUTHORITATIVE = 203
    HTTP_NOT_ACCEPTABLE = 406
    HTTP_NOT_EXTENDED = 510
    HTTP_NOT_FOUND = 404
    HTTP_NOT_IMPLEMENTED = 501
    HTTP_NOT_MODIFIED = 304
    HTTP_NO_CONTENT = 204
    HTTP_OK = 200
    HTTP_PARTIAL_CONTENT = 206
    HTTP_PAYMENT_REQUIRED = 402
    HTTP_PRECONDITION_FAILED = 412
    HTTP_PROCESSING = 102
    HTTP_PROXY_AUTHENTICATION_REQUIRED = 407
    HTTP_RANGE_NOT_SATISFIABLE = 416
    HTTP_REQUEST_ENTITY_TOO_LARGE = 413
    HTTP_REQUEST_TIME_OUT = 408
    HTTP_REQUEST_URI_TOO_LARGE = 414
    HTTP_RESET_CONTENT = 205
    HTTP_SEE_OTHER = 303
    HTTP_SERVICE_UNAVAILABLE = 503
    HTTP_SWITCHING_PROTOCOLS = 101
    HTTP_TEMPORARY_REDIRECT = 307
    HTTP_UNAUTHORIZED = 401
    HTTP_UNPROCESSABLE_ENTITY = 422
    HTTP_UNSUPPORTED_MEDIA_TYPE = 415
    HTTP_USE_PROXY = 305
    HTTP_VARIANT_ALSO_VARIES = 506
    HTTP_VERSION_NOT_SUPPORTED = 505
    LENGTH_REQUIRED = 411
    METHODS = 64
    METHOD_NOT_ALLOWED = 405
    MOVED = 301
    MULTIPLE_CHOICES = 300
    M_CONNECT = 4
    M_COPY = 11
    M_DELETE = 3
    M_GET = 0
    M_INVALID = 26
    M_LOCK = 13
    M_MKCOL = 10
    M_MOVE = 12
    M_OPTIONS = 5
    M_PATCH = 7
    M_POST = 2
    M_PROPFIND = 8
    M_PROPPATCH = 9
    M_PUT = 1
    M_TRACE = 6
    M_UNLOCK = 14
    NOT_ACCEPTABLE = 406
    NOT_FOUND = 404
    NOT_IMPLEMENTED = 501
    OK = 0
    OPT_ALL = 15
    OPT_EXECCGI = 8
    OPT_INCLUDES = 2
    OPT_INCNOEXEC = 32
    OPT_INDEXES = 1
    OPT_MULTI = 128
    OPT_NONE = 0
    OPT_SYM_LINKS = 4
    OPT_SYM_OWNER = 64
    OPT_UNSET = 16
    PARTIAL_CONTENT = 206
    PRECONDITION_FAILED = 412
    REDIRECT = 302
    REMOTE_DOUBLE_REV = 3
    REMOTE_HOST = 0
    REMOTE_NAME = 1
    REMOTE_NOLOOKUP = 2
    REQUEST_CHUNKED_DECHUNK = 2
    REQUEST_CHUNKED_ERROR = 1
    REQUEST_NO_BODY = 0
    SATISFY_ALL = 0
    SATISFY_ANY = 1
    SATISFY_NOSPEC = 2
    SERVER_ERROR = 500
    USE_LOCAL_COPY = 304
    VARIANT_ALSO_VARIES = 506


    ### Dummy mod_ruby object base class
    class ModRubySimObject
        @derivatives = {}
        class << self
            attr_reader :derivatives
        end
        
        def self::inherited( mod )
            @derivatives[ mod ] = caller( 1 ).first.split(/:/)
			$deferr.puts "Registering simulated %s at %p" % 
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
			$deferr.puts "Installing method at line %d in %s" % [ line, file ]
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
                
                $deferr.puts "call to missing method %s" % [ sym ]

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
    def add_version_component
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
		Dir.pwd
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
        def initialize( uri=nil )
            @uri = uri
			@server = nil
			@allowed = Apache::M_GET | Apache::M_POST
			@paramtable = {}
			@sync_header = false
			@content_type = 'text/html'
			@hostname = 'localhost'
			@path_info = ''
			@options = {}
			@uploads = {}
        end

		attr_writer :server
		attr_accessor :allowed, :sync_header, :content_type, :uri,
			:hostname, :paramtable, :cookies, :options, :uploads,
			:path_info
		alias_method :params, :paramtable

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
			 	$deferr.puts "#{sym.to_s.upcase}: #{msg}" if $DEBUG
			}
		end
		
		def admin
			"jrandomhacker@localhost"
		end
    end

    class Table < ModRubySimObject
    end   
          
    class Connection < ModRubySimObject
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

