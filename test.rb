#!/usr/bin/ruby
#
#	Test suite for Arrow
#
#

BEGIN {
	$:.unshift "lib", "redist", "tests/lib"

	require './utils'
	include UtilityFunctions

	verboseOff {
		require "arrow/logger"
		logfile = File::open( 'test.log', File::CREAT|File::WRONLY|File::TRUNC )
		logfile.sync = true

		Arrow::Logger.global.outputters <<
			Arrow::Logger::Outputter::create('file', logfile)
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
$Apache = true

# Parse command-line switches
ARGV.options {|oparser|
	oparser.banner = "Usage: #$0 [options] [TARGETS]\n"

	oparser.on( "--debug", "-d", TrueClass, "Turn debugging on" ) {
		$DEBUG = true
		Arrow::Logger::global.outputters <<
			Arrow::Logger::Outputter::create( 'file', $stderr, "STDERR" )
		Arrow::Logger::global.level = :debug
		debugMsg "Turned debugging on."
	}

	oparser.on( "--verbose", "-v", TrueClass, "Make progress verbose" ) {
		$VERBOSE = true
		debugMsg "Turned verbose on."
	}

	oparser.on( "--no-apache", "-n", TrueClass,
		"Skip the tests which require an installed Apache httpd." ) {
		$Apache = false
		debugMsg "Skipping apache-based tests"
	}

	# Handle the 'help' option
	oparser.on( "--help", "-h", "Display this text." ) {
		$stderr.puts oparser
		exit!(0)
	}

	oparser.parse!
}

verboseOff {
	require 'arrowtestcase'
	require 'find'
	require 'test/unit'
	require 'test/unit/testsuite'
	require 'test/unit/ui/console/testrunner'
}

# Parse test patterns
ARGV.each {|pat| patterns << Regexp::new( pat, Regexp::IGNORECASE )}
$stderr.puts "#{patterns.length} patterns given on the command line"

### Load all the tests from the tests dir
Find.find("tests") {|file|
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
			suite = Test::Unit::TestSuite.new( "Arrow Web Application Test Suite" )

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
$SAFE = safelevel
Test::Unit::UI::Console::TestRunner.new( ArrowTests ).start




