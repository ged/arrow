#!/usr/bin/ruby
# 
# This file contains the SubclassedHello class, a derivative of the Hello
# applet to test applet inheritance.
# 
# == Rcsid
# 
# $Id: subclassed-hello.rb,v 1.1 2003/12/08 20:40:05 deveiant Exp $
# 
# == Authors
# 
# * Martin Chase <stillflame@FaerieMUD.org>
# 

begin
	basedir = File::dirname(__FILE__)
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
end

require 'superhello'

Arrow::Logger.global.debug "SubclassedHello: Past the requires"

### An applet for testing inheritance from other derived applets
class SubclassedHello < SuperHello

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: subclassed-hello.rb,v 1.1 2003/12/08 20:40:05 deveiant Exp $

	# Applet signature
	Signature = {
		:name => "Hello World (Subclassed)",
		:description => %{A modified 'hello world' applet to figure out if subclassing works.},
		:uri => "subhello",
		:maintainer => "stillflame@FaerieMUD.org",
	}

end # class SubclassedHello
