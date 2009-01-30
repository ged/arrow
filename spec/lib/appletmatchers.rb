#!/usr/bin/env ruby

# These are a collection of RSpec matchers to make unit testing of Arrow
# applets easier.

require 'apache/fakerequest'
require 'arrow'

require 'spec/matchers'

### Fixturing functions
module Arrow::AppletMatchers

	STATUS_NAMES = {
		100 => 'CONTINUE',
		101 => 'SWITCHING_PROTOCOLS',
		102 => 'PROCESSING',

		200 => 'OK',
		201 => 'CREATED',
		202 => 'ACCEPTED',
		203 => 'NON_AUTHORITATIVE',
		204 => 'NO_CONTENT',
		205 => 'RESET_CONTENT',
		206 => 'PARTIAL_CONTENT',
		207 => 'MULTI_STATUS',

		300 => 'MULTIPLE_CHOICES',
		301 => 'MOVED',
		302 => 'REDIRECT',
		303 => 'SEE_OTHER',
		304 => 'NOT_MODIFIED',
		305 => 'USE_PROXY',
		307 => 'TEMPORARY_REDIRECT',

		400 => 'BAD_REQUEST',
		401 => 'UNAUTHORIZED',
		402 => 'PAYMENT_REQUIRED',
		403 => 'FORBIDDEN',
		404 => 'NOT_FOUND',
		405 => 'METHOD_NOT_ALLOWED',
		406 => 'NOT_ACCEPTABLE',
		407 => 'PROXY_AUTHENTICATION_REQUIRED',
		408 => 'REQUEST_TIME_OUT',
		409 => 'CONFLICT',
		410 => 'GONE',
		411 => 'LENGTH_REQUIRED',
		412 => 'PRECONDITION_FAILED',
		413 => 'REQUEST_ENTITY_TOO_LARGE',
		414 => 'REQUEST_URI_TOO_LARGE',
		415 => 'UNSUPPORTED_MEDIA_TYPE',
		416 => 'RANGE_NOT_SATISFIABLE',
		417 => 'EXPECTATION_FAILED',
		422 => 'UNPROCESSABLE_ENTITY',
		423 => 'LOCKED',
		424 => 'FAILED_DEPENDENCY',

		500 => 'SERVER_ERROR',
		501 => 'NOT_IMPLEMENTED',
		502 => 'BAD_GATEWAY',
		503 => 'SERVICE_UNAVAILABLE',
		504 => 'GATEWAY_TIME_OUT',
		505 => 'VERSION_NOT_SUPPORTED',
		506 => 'VARIANT_ALSO_VARIES',
		507 => 'INSUFFICIENT_STORAGE',
		510 => 'NOT_EXTENDED',
	}


	### A matcher that wraps an applet's #run method and can assert things about the
	### generated response.
	class RunWithMatcher
		
		### Create a new FinishWithMatcher that should finish with the given
		### 
		def initialize( status, message=:any_message )
			@expected_status  = status
			@expected_message = message
			@actual = nil
		end
		
		
		### Returns true if the code executed in the given +procobj+ calls
		### 'finish_with' 
		def matches?( procobj )
			begin
				@actual = catch( :finish, &procobj )
			rescue => err
				@actual = err
			ensure
				return statuses_match? && messages_match?
			end
		end
		
		### Returns true if the expected status is the same as the actual
		### status
		def statuses_match?
			return @actual.is_a?( Hash ) &&
				@actual.key?( :status ) &&
				@actual[:status] == @expected_status
		end

		### Returns true if the expected message matches the actual message
		def messages_match?
			return false unless @actual.is_a?( Hash ) && @actual.key?( :message )
			return true if @expected_message == :any_message

			case @expected_message
			when String
				return @actual[:message] == @expected_message
			when Regexp
				return @actual[:message] =~ @expected_message
			else
				return false
			end
		end


		### Generate an appropriate failure message for a #should match
		### failure.
		def failure_message
			if @actual
				return "expected %s, got %p" % [
					self.expectation_description,
					@actual
				]
			else
				return 
			end
		end


		### Generate an appropriate failure message for a #should_not match
		### failure.
		def negative_failure_message
			if @expected_status
				return "expected %s" % self.description
			else
				return "expected a normal return, but applet finished with %d (%s): %s"
			end
		end


		### Return a human-readable description of the matcher
		def description
			return "the action to %s" % self.expectation_description
		end
		
		
		### Return a description of the expected status and message.
		def expectation_description
			if @expected_message.is_a?( Regexp )
				return "finish_with %d (%s) status and a message which matches %p" % [
					@expected_status,
					STATUS_NAMES[@expected_status],
					@expected_message
				]
			else
				return "finish_with %d (%s) status and a message which is %p" % [
					@expected_status,
					STATUS_NAMES[@expected_status],
					@expected_message
				]
			end
		end
	end


	### A matcher that wraps an action method and can trap abnormal responses
	class FinishWithMatcher
		
		### Create a new FinishWithMatcher that should finish with the given
		### 
		def initialize( status, message=:any_message )
			@expected_status  = status
			@expected_message = message
			@actual = nil
		end
		
		
		### Returns true if the code executed in the given +procobj+ calls
		### 'finish_with' 
		def matches?( procobj )
			begin
				@actual = catch( :finish, &procobj )
			rescue => err
				@actual = err
			ensure
				return statuses_match? && messages_match?
			end
		end
		
		### Returns true if the expected status is the same as the actual
		### status
		def statuses_match?
			return @actual.is_a?( Hash ) &&
				@actual.key?( :status ) &&
				@actual[:status] == @expected_status
		end

		### Returns true if the expected message matches the actual message
		def messages_match?
			return false unless @actual.is_a?( Hash ) && @actual.key?( :message )
			return true if @expected_message == :any_message

			case @expected_message
			when String
				return @actual[:message] == @expected_message
			when Regexp
				return @actual[:message] =~ @expected_message
			else
				return false
			end
		end


		### Generate an appropriate failure message for a #should match
		### failure.
		def failure_message
			if @actual
				return "expected %s, got %p" % [
					self.expectation_description,
					@actual
				]
			else
				return 
			end
		end


		### Generate an appropriate failure message for a #should_not match
		### failure.
		def negative_failure_message
			if @expected_status
				return "expected %s" % self.description
			else
				return "expected a normal return, but applet finished with %d (%s): %s"
			end
		end


		### Return a human-readable description of the matcher
		def description
			return "the action to %s" % self.expectation_description
		end
		
		
		### Return a description of the expected status and message.
		def expectation_description
			if @expected_message.is_a?( Regexp )
				return "finish_with %d (%s) status and a message which matches %p" % [
					@expected_status,
					STATUS_NAMES[@expected_status],
					@expected_message
				]
			else
				return "finish_with %d (%s) status and a message which is %p" % [
					@expected_status,
					STATUS_NAMES[@expected_status],
					@expected_message
				]
			end
		end
	end


	### The main matcher expression. Assert that the given block is exited via a thrown status
	### code of +status+ and a message which matches +message+ (if given).
	def run_with( status, message=:any_message )
		return Arrow::AppletMatchers::RunWithMatcher.new( status, message )
	end

	### The action method matcher expression. Assert that the given block is exited via a 
	### thrown status code of +status+ and a message which matches +message+ (if given).
	def finish_with( status, message=:any_message )
		return Arrow::AppletMatchers::FinishWithMatcher.new( status, message )
	end

end


