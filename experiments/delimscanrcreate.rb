#!/usr/bin/ruby
# $Id$
#
# Benchmark DelimScanner creation to see whether using a single instance to
# parse tag bodies is worth the additional complexity.
# 
# Time-stamp: <24-Aug-2003 16:11:25 deveiant>
#

require 'benchmark'
require 'delimscanner'

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib", "#{base}/redist"

	require "#{base}/utils.rb"
	include UtilityFunctions
}

header "DelimScanner Benchmarks"

testString = "some testing text"
n = 50000

Benchmark.bm( 15 ) do |x|
	scanner = nil
	x.report("Create: ") {
		n.times do
			scanner = DelimScanner.new( testString )
		end
	}
	scanner = DelimScanner.new( testString )
	x.report("Setstring: ") {
		n.times do
			scanner.string = testString
		end
	}
end


# DelimScanner Benchmarks
#                      user     system      total        real
# Create:          0.620000   0.010000   0.630000 (  0.627169)
# Setstring:       0.420000   0.000000   0.420000 (  0.417103)

# Conclusion: inconclusive, but I'll err on the side of speed.

