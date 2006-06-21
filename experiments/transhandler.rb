


class DumpingTransHandler
	def translate_uri( req )
		msg = "**TRANS*** path_info = %p, unparsed_uri = %p, uri = %p, script_name = %p, script_path = %p" %
			[ req.path_info, req.unparsed_uri, req.uri, req.script_name, req.script_path ]
		req.server.log_debug( msg )
	
		return Apache::DECLINED
	end
end