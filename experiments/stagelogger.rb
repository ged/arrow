#!/usr/bin/env ruby -w

#
# Not so much an experiment as documentation-generator: Shows the stages of a
# request which call it, along with the method being called.
#
# Usage:
#
#   RubyRequire stagelogger
#   
#   RubyChildInitHandler       StageLogger.instance
#   RubyPostReadRequestHandler StageLogger.instance
#   RubyTransHandler           StageLogger.instance  
#   
#   <Location /stages>
#   	RubyInitHandler			   StageLogger.instance
#   	RubyHeaderParserHandler	   StageLogger.instance
#   	RubyAccessHandler		   StageLogger.instance
#   	RubyAuthenHandler		   StageLogger.instance
#   	RubyAuthzHandler		   StageLogger.instance
#   	RubyTypeHandler			   StageLogger.instance
#   	RubyFixupHandler		   StageLogger.instance
#   	RubyLogHandler			   StageLogger.instance
#   	RubyCleanupHandler         StageLogger.instance
#   </Location>
#

require 'singleton'

class StageLogger
	include Singleton

	MethodMap = {
		:child_init		   => 'ChildInitHandler',
		:post_read_request => 'PostReadRequestHandler',
		:translate_uri	   => 'TransHandler',
		:init			   => 'InitHandler',
		:header_parse	   => 'HeaderParserHandler',
		:check_access	   => 'AccessHandler',
		:authorize		   => 'AuthzHandler',
		:authenticate	   => 'AuthenHandler',
		:find_types		   => 'TypeHandler',
		:fixup			   => 'FixupHandler',
		:handler		   => 'Content Handler',
		:log_transaction   => 'LogHandler',
		:cleanup		   => 'CleanupHandler',
	}

	def method_missing( sym, req, *args )
		if MethodMap.key?( sym )
			stage = MethodMap[ sym ]
			req.server.log_error "in %s [%s]: %p" %
				[stage, sym, args]
			return Apache::DECLINED
		else
			super
		end
	end

	def handler( req )
		req.content_type = "text/plain"
		req.puts "In content handler."
		req.server.log_error( "in content handler" )

		return Apache::OK
	end
end


# Results:

# [Fri Aug  6 20:15:22 2004] [error] in child_init: []
# [Fri Aug  6 20:15:25 2004] [error] in post_read_request: []
# [Fri Aug  6 20:15:25 2004] [error] in translate_uri: []
# [Fri Aug  6 20:15:25 2004] [error] in init: []
# [Fri Aug  6 20:15:25 2004] [error] in header_parse: []
# [Fri Aug  6 20:15:25 2004] [error] in check_access: []
# [Fri Aug  6 20:15:25 2004] [error] in find_types: []
# [Fri Aug  6 20:15:26 2004] [error] in fixup: []
# [Fri Aug  6 20:15:26 2004] [error] [client 127.0.0.1] File does not exist: /stages
# [Fri Aug  6 20:15:26 2004] [error] in log_transaction: []
# [Fri Aug  6 20:15:26 2004] [error] in cleanup: []

