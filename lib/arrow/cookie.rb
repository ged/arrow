#!/usr/bin/env ruby
# 
# This file contains the Arrow::Cookie class, a class for parsing and
# generating HTTP cookies.
# 
# Large parts of this code were copied from the Webrick::Cookie class
# in the Ruby standard library. The copyright statements for that module
# are:
# 
#   Author: IPR -- Internet Programming with Ruby -- writers
#   Copyright (c) 2000, 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
#   Copyright (c) 2002 Internet Programming with Ruby writers. All rights
#   reserved.
# 
# == Subversion Id
# 
#   $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# :include: COPYRIGHT
# 
# ---
# 
# Please see the file docs/COPYRIGHT for licensing details.
# 

require 'date'
require 'time'
require 'uri'


### A class for parsing and generating HTTP cookies
class Arrow::Cookie < Arrow::Object

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	CookieDateFormat = '%a, %d-%b-%Y %H:%M:%S GMT'

	### Strip surrounding double quotes from a copy of the specified string 
	### and return it.
	def self::dequote( string )
		/^"((?:[^"]+|\\.)*)"/.match( string ) ? $1 : string.dup
	end


	### Parse a cookie value string, returning an Array of Strings
	def self::parse_valuestring( valstr )
		return [] unless valstr
		valstr = dequote( valstr )

		return valstr.split('&').collect{|str| URI.unescape(str) }
	end


	### RFC 2109: HTTP State Management Mechanism
	# When it sends a request to an origin server, the user agent sends a
	# Cookie request header to the origin server if it has cookies that are
	# applicable to the request, based on
	#
	#   * the request-host;
	#   * the request-URI;
	#   * the cookie's age.
	#
	# The syntax for the header is:
	#
	# cookie          =       "Cookie:" cookie-version
	#                            1*((";" | ",") cookie-value)
	# cookie-value    =       NAME "=" VALUE [";" path] [";" domain]
	# cookie-version  =       "$Version" "=" value
	# NAME            =       attr
	# VALUE           =       value
	# path            =       "$Path" "=" value
	# domain          =       "$Domain" "=" value

	CookieVersion = /\$Version\s*=\s*(.+)\s*[,;]/
	CookiePath = /\$Path/i
	CookieDomain = /\$Domain/i

	### RFC2068: Hypertext Transfer Protocol -- HTTP/1.1 
	# CTL            = <any US-ASCII control character
	#                  (octets 0 - 31) and DEL (127)>
	# token          = 1*<any CHAR except CTLs or tspecials>
	#
	# tspecials      = "(" | ")" | "<" | ">" | "@"
	#                | "," | ";" | ":" | "\" | <">
	#                | "/" | "[" | "]" | "?" | "="
	#                | "{" | "}" | SP | HT
	CTLs      = "[:cntrl:]"
	TSpecials = Regexp.quote ' "(),/:;<=>?@[\\]{}'
	NonTokenChar = /[#{CTLs}#{TSpecials}]/s
	HTTPToken = /\A[^#{CTLs}#{TSpecials}]+\z/s
	
	### Parse the specified 'Cookie:' +header+ value and return a Hash of 
	### one or more new Arrow::Cookie objects, keyed by name.
	def self::parse( header )
		return {} if header.nil? or header.empty?
		Arrow::Logger[self].debug "Parsing cookie header: %p" % [ header ]
		cookies = []
		version = 0
		header = header.strip

		# "$Version" = value
		if CookieVersion.match( header )
			Arrow::Logger[self].debug "  Found cookie version %p" % [ $1 ]
			version = Integer( dequote($1) )
			header.slice!( CookieVersion )
		end

		# 1*((";" | ",") NAME "=" VALUE [";" path] [";" domain])
		header.split( /[,;]\s*/ ).each do |pair|
			Arrow::Logger[self].debug "  Found pair %p" % [ pair ]
			key, valstr = pair.split( /=/, 2 ).collect {|s| s.strip }
			
			case key
			when CookiePath
				Arrow::Logger[self].debug "    -> cookie-path %p" % [ valstr ]
				cookies.last.path = dequote( valstr ) unless cookies.empty?

			when CookieDomain
				Arrow::Logger[self].debug "    -> cookie-domain %p" % [ valstr ]
				cookies.last.domain = dequote( valstr ) unless cookies.empty?

			when HTTPToken
				values = parse_valuestring( valstr )
				Arrow::Logger[self].debug "    -> cookie-values %p" % [ values ]
				cookies << new( key, values, :version => version )
				
			else
				Arrow::Logger[self].warning \
					"Malformed cookie header %p: %p is not a valid token; ignoring" %
					[ header, key ]
			end
		end

		# Turn the array into a Hash, ignoring all but the first instance of
		# a cookie with the same name
		return cookies.inject({}) do |hash,cookie|
			hash[cookie.name] = cookie unless hash.key?( cookie.name )
			hash
		end
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new Arrow::Cookie object with the specified +name+ and 
	### +values+.
	def initialize( name, values, options={} )
		values = [ values ] unless values.is_a?( Array )
		@name = name
		@values = values

		@domain = nil
		@path = nil
		@secure = false
		@comment = nil
		@max_age = nil
		@expires = nil
		@version = 0
		
		options.each do |meth, val|
			self.__send__( "#{meth}=", val )
		end
	end



	######
	public
	######

	# The name of the cookie
	attr_accessor :name

	# The Array of cookie values
	attr_accessor :values

	# The cookie version. 0 (the default) is fine for most uses
	attr_accessor :version
	
	# The domain the cookie belongs to
	attr_reader :domain
	
	# The path the cookie applies to
	attr_accessor :path
	
	# The cookie's 'secure' flag.
	attr_writer :secure

	# The cookie's expiration (a Time object)
	attr_reader :expires
	
	# The lifetime of the cookie, in seconds.
	attr_reader :max_age

	# Because cookies can contain private information about a
	# user, the Cookie attribute allows an origin server to document its
	# intended use of a cookie.  The user can inspect the information to
	# decide whether to initiate or continue a session with this cookie.
	attr_accessor :comment


	### Return the first value stored in the cookie as a String.
	def value
		@values.first
	end


	### Returns +true+ if the secure flag is set
	def secure?
		return @secure ? true : false
	end
	
	# Set the lifetime of the cookie. The value is a decimal non-negative
	# integer.  After +delta_seconds+ seconds elapse, the client should
	# discard the cookie.  A value of zero means the cookie should be
	# discarded immediately.
	def max_age=( delta_seconds )
		@max_age = Integer( delta_seconds )
	end


	### Set the domain for which the cookie is valid.
	def domain=( newdomain )
		newdomain = ".#{newdomain}" unless newdomain[0] == ?.
		@domain = newdomain.dup
	end
	

	### Set the cookie's expires field. The value can be either a Time object 
	### or a String in any of the following formats:
	### +30s::
	### 	30 seconds from now
	### +10m::
	### 	ten minutes from now
	### +1h::
	### 	one hour from now
	### -1d::
	### 	yesterday (i.e. "ASAP!")
	### now::
	### 	immediately
	### +3M::
	### 	in three months
	### +10y::
	### 	in ten years time
	### Thursday, 25-Apr-1999 00:40:33 GMT::
	### 	at the indicated time & date
	def expires=( time )
		case time
		when NilClass
			@expires = nil
			
		when Date
			@expires = Time.parse( time.ctime )
			
		when Time
			@expires = time
			
		else
			@expires = parse_time_delta( time )
		end
	rescue => err
		raise err, caller(1)
	end


	### Set the cookie expiration to a time in the past
	def expire!
		self.expires = Time.at(0)
	end
	

	
	### Return the cookie as a String
	def to_s
		rval = "%s=%s" % [ self.name, make_valuestring(self.values) ]

		rval << make_field( "Version", self.version ) if self.version.nonzero?
		rval << make_field( "Domain", self.domain )
		rval << make_field( "Expires", make_cookiedate(self.expires) ) if self.expires
		rval << make_field( "Max-Age", self.max_age )
		rval << make_field( "Comment", self.comment )
		rval << make_field( "Path", self.path )

		rval << "; " << "Secure" if self.secure?

		return rval
	end


	### Return +true+ if other_cookie has the same name as the receiver.
	def eql?( other_cookie )
		return (self.name == other_cookie.name) ? true : false
	end
	

	### Generate a Fixnum hash value for this object. Uses the hash of the cookie's name.
	def hash
		return self.name.hash
	end
	
	

	#######
	private
	#######

	### Make a cookie field for appending to the outgoing header for the
	### specified +value+ and +field_name+. If +value+ is nil, an empty
	### string will be returned.
	def make_field( field_name, value )
		return '' if value.nil? || (value.is_a?(String) && value.empty?)
		
		return "; %s=%s" % [
			field_name.capitalize,
			value
		]
	end
	

	# Number of seconds in the various offset types
	Seconds = {
		's' => 1,
		'm' => 60,
		'h' => 60*60,
		'd' => 60*60*24,
		'M' => 60*60*24*30,
		'y' => 60*60*24*365,
	}

	### Parse a time delta like those accepted by #expires= into a Time 
	### object.
	def parse_time_delta( time )
		return Time.now if time.nil? || time == 'now'
		return Time.at( Integer(time) ) if /^\d+$/.match( time )
		
		if /^([+-]?(?:\d+|\d*\.\d*))([mhdMy]?)/.match( time )
			offset = (Seconds[$2] || 1) * Integer($1)
			return Time.now + offset
		end
		
		return Time.parse( time )
	end

	### Make a uri-escaped value string for the given +values+
	def make_valuestring( values )
		values.collect {|val| URI.escape(val, NonTokenChar) }.join('&')
	end


	### Make an RFC2109-formatted date out of +date+.
	def make_cookiedate( date )
		return date.gmtime.strftime( CookieDateFormat )
	end
	

	### Quote a copy of the given string and return it.
	def quote( val )
		%q{"%s"} % [ val.to_s.gsub(/"/, '\\"') ]
	end

end # class Arrow::Cookie
