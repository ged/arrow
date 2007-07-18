#!/usr/bin/env ruby
#
#	Test suite for Arrow
#
#

BEGIN {
	$basedir = File.expand_path( File.dirname(__FILE__) )
	["lib", "tests/lib", "redist"].each do |subdir|
		$LOAD_PATH.unshift File.join( $basedir, subdir )
	end

	require "#{$basedir}/utils"
	include UtilityFunctions

	verboseOff {
		require "arrow/logger"
		loguri = 'file://' + File.join( $basedir, "test.log" )

		Arrow::Logger.global.outputters <<
			Arrow::Logger::Outputter.create( loguri )
		Arrow::Logger.global.level = :debug
	}
}

require 'optparse'

# Turn off output buffering
$stderr.sync = $stdout.sync = true

# Initialize variables
safelevel = 0
patterns = []
requires = []
$DebugPattern = nil

# Parse command-line switches
ARGV.options {|oparser|
	oparser.banner = "Usage: #$0 [options] [TARGETS]\n"

	oparser.on( "--debug[=PATTERN]", "-d[=PATTERN]", String,
		"Turn debugging on (for tests which match PATTERN)" ) {|arg|
		if arg
			$DebugPattern = Regexp.new( arg )
			puts "Turned debugging on for %p." % $DebugPattern
		else
			Arrow::Logger.global.outputters <<
				Arrow::Logger::Outputter.create( 'file:stderr', "STDERR" )
			Arrow::Logger.global.level = :debug
			$DEBUG = true
			debugMsg "Turned debugging on globally."
		end
	}

	oparser.on( "--verbose", "-v", TrueClass, "Make progress verbose" ) {
		$VERBOSE = true
		debugMsg "Turned verbose on."
	}

	# Handle the 'help' option
	oparser.on( "--help", "-h", "Display this text." ) {
		$stderr.puts oparser
		exit!(0)
	}

	oparser.parse!
}

verboseOff {
	require 'arrow/testcase'
	require 'find'
	require 'test/unit'
	require 'test/unit/testsuite'
	require 'test/unit/ui/console/testrunner'
}

# Parse test patterns
ARGV.each {|pat| patterns << Regexp.new( pat, Regexp::IGNORECASE )}
$stderr.puts "#{patterns.length} patterns given on the command line:",
    patterns.collect {|pat| "  " + pat.to_s }.join( "\n" )

### Load all the tests from the tests dir
Find.find( File.join($basedir, "tests") ) {|file|
	Find.prune if /\/\./ =~ file or /~$/ =~ file
	Find.prune if /TEMPLATE/ =~ file
	next if File.stat( file ).directory?

 	unless patterns.empty?
 		Find.prune unless patterns.find {|pat| pat =~ file}
 	end

	debugMsg "Considering '%s': " % file
	next unless file =~ /\.tests.rb$/
	debugMsg "Requiring '%s'..." % file
	require "#{file}"
	requires << file
}

$stderr.puts "Required #{requires.length} files."
unless patterns.empty?
	$stderr.puts "[" + requires.sort.join( ", " ) + "]"
end

class ArrowTests
	class << self
		def suite
			suite = Test::Unit::TestSuite.new( "Arrow Web Application Framework" )

			if suite.respond_to?( :add )
				ObjectSpace.each_object( Class ) {|klass|
					suite.add( klass.suite ) if klass < Arrow::TestCase
				}
			else
				ObjectSpace.each_object( Class ) {|klass|
					suite << klass.suite if klass < Arrow::TestCase
				}			
			end

			return suite
		end
	end
end

# Run tests
Dir.chdir( $basedir ) do
	$SAFE = safelevel
	Test::Unit::UI::Console::TestRunner.new( ArrowTests ).start
end






