#!/usr/bin/env ruby
# 
# The SubclassedHello class, a derivative of the Hello
# applet to test applet inheritance.
# 
# == Authors
# 
# * Martin Chase <stillflame@FaerieMUD.org>
# 

begin
	basedir = File.dirname(__FILE__)
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
end

require 'superhello'

Arrow::Logger.global.debug "SubclassedHello: Past the requires"

### An applet for testing inheritance from other derived applets
class SubclassedHello < SuperHello


	# Applet signature
	Signature = {
		:name => "Hello World (Subclassed)",
		:description => %{A modified 'hello world' applet to figure out if subclassing works.},
		:uri => "subhello",
		:maintainer => "stillflame@FaerieMUD.org",
	}

end # class SubclassedHello