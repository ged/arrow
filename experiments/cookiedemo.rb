#!/usr/bin/ruby

# Install in Apache like:
# 

class CookieDemo

	### Content handler
  	def self::handler( req )

		# Dump all the cookies in plain text
		response = "mod_ruby Cookie Demo\n\n"
		response << "%d cookies in your request.\n\n" % req.cookies.length
		
    	for name, cookie in req.cookies
			response << name + "\n"
			response << "  domain: %s\n" % cookie.domain
			response << "  expires: %s\n" % cookie.expires
			response << "  name: %s\n" % cookie.name
			response << "  path: %s\n" % cookie.path
			response << "  secure?: %s\n" % cookie.secure ? "yes" : "no"
			response << "  values:\n    %s\n" % cookie.values.join("\n    ")
			response << "\n"
		end

		# Set a cookie of our own
		ourcookie = Apache::Cookie.new( req, 
			:name => "last-run",
			:value => Time.now.to_s,
			:expires => "+10m",
			:path => req.uri
			)
		
		# Add the cookie to the response header
		ourcookie.bake

		response << "\n\nResponse headers: \n\n"
		req.headers_out.each do |key, val|
			response << "  #{key}: #{val}\n"
		end
		
		# Finish and send response headers
		req.content_type = "text/plain"
		req.send_http_header
		
		# Send the body of the response
		req.print( response )
		
		return Apache::OK
  	end


end