require 'singleton'

class SafeLevel
	include Singleton
	
	def handler( req )
		req.content_type = "text/plain"
		req.send_http_header
		req.print "$SAFE level is #$SAFE"
		
		return Apache::OK
	end
end

