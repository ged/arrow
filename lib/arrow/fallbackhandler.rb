#!/usr/bin/env ruby
# 
# This file contains the Arrow::FallbackHandler class, a request handler for
# Arrow that is used to handle misconfigured handler requests.
# 
# == Rcsid
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the BASE directory for licensing details.
#


### A little handler to be returned for keys given to the dispatcher for which
### real instances haven't been created.
class Arrow::FallbackHandler

	### Create a new instance for the given +key+ and +instances+.
	def initialize( key, instances )
		@key = key
		@instances = instances
	end


	### Handle a request with output that explains what the problem is.
	def handler( req )
		req.content_type = "text/plain"
		req.send_http_header
		req.print <<-EOF

Arrow Configuration Error

This URL is configured to be handled by the dispatcher keyed with '#{@key.inspect}',
but there was no dispatcher associated with that key. The instances I know about 
are:

#{@instances.collect {|k,d| "-- #{k.inspect} --\n\n#{d.inspect}"}.join("\n\n")}

		EOF

		return Apache::OK
	end
end


