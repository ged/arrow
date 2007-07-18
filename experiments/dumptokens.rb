#!/usr/bin/env ruby
#
# A little hack to dump a token stream for any given code.
# 
# Time-stamp: <10-Jan-2004 09:38:39 deveiant>
#

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
}

require 'arrow/rubytokenreactor'
require 'arrow/logger'

if $DEBUG
	def colored( prompt, *args )
		return ansiCode( *(args.flatten) ) + prompt + ansiCode( 'reset' )
	end

	puts "Turning on logging..."
	format = colored( %q{#{time} [#{level}]: }, 'cyan' ) +
		colored( %q{#{name} #{frame ? '('+frame+')' : ''}: #{msg[0,1024]}}, 'white' )
	outputter = Arrow::Logger::Outputter.create( 'file', $deferr, ".irbrc", format )
	Arrow::Logger.global.outputters << outputter
	Arrow::Logger.global.level = :debug

	Arrow::Logger.global.notice "Logging enabled."
end	

def showToken( tr, tok, *args )
	message "[l %d, c %d] %p: %p\n" % [
		tr.lineno,
		tr.column,
		tok,
		args
	]
end


if ARGV.empty?
	until (line = prompt( "Eval" )).empty?
		Arrow::RubyTokenReactor.parse( line, :all, &method(:showToken) )
	end
else
	ARGV.each {|arg|
		tr = nil

		if File.file?( arg )
			tr = Arrow::RubyTokenReactor.new( File.open(arg, "r") )
		else
			tr = Arrow::RubyTokenReactor.new( arg )
		end		

		tr.onEvents( :all, &method(:showToken) ) 
		tr.parse
	}
end
