#!/usr/bin/ruby
#
# A little experiment to see if dup'ing a Module used as a namespace duplicates
# its local variables, too.
# 
# Time-stamp: <24-Aug-2003 16:11:57 deveiant>
#

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
}

$yaml = false

namespace1 = Module.new
scope1 = namespace1.instance_eval { binding }
eval( "def foo ; :bar ; end", scope1 )

namespace2 = namespace1.dup
scope2 = namespace2.instance_eval { binding }

try( "to fetch foo from the duplicated scope" ) {
	eval( "foo", scope2 )
}


