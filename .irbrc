#!/usr/bin/ruby

puts ">>> Adding lib and ext to load path..."
$LOAD_PATH.unshift( "lib", "redist" )

require './utils'
include UtilityFunctions

def colored( prompt, *args )
	return ansiCode( *(args.flatten) ) + prompt + ansiCode( 'reset' )
end


# Modify prompt to do highlighting unless we're running in an inferior shell.
unless ENV['EMACS']
	IRB.conf[:PROMPT][:arrow] = { # name of prompt mode
		:PROMPT_I => colored( "%N(%m):%03n:%i>", %w{bold white on_blue} ) + " ",
		:PROMPT_S => colored( "%N(%m):%03n:%i%l", %w{white on_blue} ) + " ",
		:PROMPT_C => colored( "%N(%m):%03n:%i*", %w{white on_blue} ) + " ",
		:RETURN => "    ==> %s\n\n"      # format to return value
	}
	IRB.conf[:PROMPT_MODE] = :arrow
end

# Try to require the 'arrow' library
begin
	puts "Requiring Arrow..."
	require "arrow"

	if $DEBUG
		puts "Turning on logging..."
		format = colored( %q{#{time} [#{level}]: }, 'cyan' ) +
			colored( %q{#{name} #{frame ? '('+frame+')' : ''}: #{msg[0,1024]}}, 'white' )
		outputter = Arrow::Logger::Outputter::create( 'file', $deferr, ".irbrc", format )
		Arrow::Logger::global.outputters << outputter
		Arrow::Logger::global.level = :debug

		Arrow::Logger::global.notice "Logging enabled."
	end	
rescue => e
	$stderr.puts "Ack! Arrow library failed to load: #{e.message}\n\t" +
		e.backtrace.join( "\n\t" )
end


__END__
Local Variables:
mode: ruby
