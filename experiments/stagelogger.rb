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
#       RubyHandler                StageLogger.instance
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

	### Handle any of the methods that mod_ruby handlers call, logging each of them
	### with the method that was called, the handler, and the arguments it was called 
	### with.
	def method_missing( sym, req, *args )
		if MethodMap.key?( sym )
			stage = MethodMap[ sym ]
			req.server.log_error "StageLogger {%d}>> in %s %s(%p, %p)" % [
				Process.pid,
				stage,
				sym,
				req,
				args
			  ]
		else
			req.server.log_error "StageLogger {%d}>> unknown handler: %s(%p, %p)" % [
				Process.pid,
				sym,
				req,
				args
			  ]
		end

		return Apache::DECLINED
	end


	### Handle the content handler differently so requests don't 404.
	def handler( req )
		req.content_type = "text/plain"
		req.puts "In content handler."
		req.server.log_error "StageLogger {%d}>> RubyHandler: handler(%p)" % [
			Process.pid,
			req
		  ]

		return Apache::OK
	end
end


# Results:

# [Sat Nov 13 10:50:12 2010] [error] StageLogger {42170} \
# 	>> in ChildInitHandler child_init(#<Apache::Request:0x102730de0>, [])
# [Sat Nov 13 10:50:22 2010] [error] StageLogger {42170} \
# 	>> in PostReadRequestHandler post_read_request(#<Apache::Request:0x1020b2798>, [])
# [Sat Nov 13 10:50:22 2010] [error] StageLogger {42170} \
# 	>> in TransHandler translate_uri(#<Apache::Request:0x1020b2798>, [])
# [Sat Nov 13 10:50:22 2010] [error] StageLogger {42170} \
# 	>> in AccessHandler check_access(#<Apache::Request:0x1020b2798>, [])
# [Sat Nov 13 10:50:22 2010] [error] StageLogger {42170} \
# 	>> in TypeHandler find_types(#<Apache::Request:0x1020b2798>, [])
# [Sat Nov 13 10:50:22 2010] [error] StageLogger {42170} \
# 	>> in FixupHandler fixup(#<Apache::Request:0x1020b2798>, [])
# [Sat Nov 13 10:50:22 2010] [error] StageLogger {42170} \
# 	>> RubyHandler: handler(#<Apache::Request:0x1020b2798>)
# [Sat Nov 13 10:50:22 2010] [error] StageLogger {42170} \
# 	>> in LogHandler log_transaction(#<Apache::Request:0x1020b2798>, [])
# [Sat Nov 13 10:50:22 2010] [error] StageLogger {42170} \
# 	>> in CleanupHandler cleanup(#<Apache::Request:0x1020a77d0>, [])
# [Sat Nov 13 10:50:22 2010] [error] StageLogger {42170} \
# 	>> in PostReadRequestHandler post_read_request(#<Apache::Request:0x1020a5ac0>, [])
# [Sat Nov 13 10:50:22 2010] [error] StageLogger {42170} \
# 	>> in TransHandler translate_uri(#<Apache::Request:0x1020a5ac0>, [])

