#!/usr/bin/ruby
# 
# This file contains the SubclassedHello class, a derivative of the Hello
# application to test application inheritance.
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

### An Arrow appserver status application.
class SubclassedHello < SuperHello

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: subclassed-hello.rb,v 1.1 2003/12/08 20:40:05 deveiant Exp $

	# Application signature
	Signature = {
		:name => "Hello World (Subclassed)",
		:description => %{A modified 'hello world' app to figure out if subclassing works.},
		:uri => "subhello",
		:maintainer => "stillflame@FaerieMUD.org",
	}

end # class SubclassedHello
