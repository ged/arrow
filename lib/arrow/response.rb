#!/usr/bin/ruby
# 
# This file contains the Arrow::Response class, an experimental derivative of
# Arrow::Object which is intended to make building a response for an
# Arrow::Transaction a little easier. It is not certain whether this class will
# be part of the release of Arrow. Suggestions welcomed.
# 
# == Rcsid
# 
# $Id: response.rb,v 1.1 2003/10/13 04:20:13 deveiant Exp $
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

require 'net/http'
require 'forwardable'

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/object'

module Arrow

	### An HTTP response class.
	class Response < Arrow::Object
		extend Forwardable

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: response.rb,v 1.1 2003/10/13 04:20:13 deveiant Exp $

		# The Array of method names to delegate to the request object
		DelegatedMethods = %w{
			<< auth_name auth_type bytes_sent cache_resp cache_resp=
			cancel connection content_encoding= content_languages
			content_languages= content_type= custom_response
			escape_html internal_redirect output_buffer print
			printf putc puts replace send_fd setup_cgi_env status
			status= status_line status_line= user user=
			write
		}


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new Arrow::Response object that will reply to the given
		### +request+ (an Apache::Request object).
		def initialize( request )
			@request = request
			@headers = request.headers_out
			@errHeaders = request.err_headers_out

			super()
		end


		######
		public
		######

		# The Apache::Request object
		attr_reader :request

		# The Apache::Table of response HTTP headers
		attr_reader :headers

		# The Apache::Table of HTTP headers which will be sent even when an
		# error occurs, and which persist across internal redirects.
		attr_reader :errHeaders

		
		# Delegate some other methods directly to the request
		def_delegators :@request, *DelegatedMethods


		#########
		protected
		#########


	end # class Response

end # module Arrow


