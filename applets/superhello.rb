#!/usr/bin/ruby
# 
# This file contains the SuperHello class, a derivative of Arrow::Applet. A
# "hello world" applet.
# 
# == Rcsid
# 
# $Id: superhello.rb,v 1.1 2003/12/08 20:40:05 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/applet'


### A superclass applet for testing inheritance
class SuperHello < Arrow::Applet

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: superhello.rb,v 1.1 2003/12/08 20:40:05 deveiant Exp $

	# Applet signature -- since it defines no 'uri' item, it shouldn't be loaded
	# by the appserver directly.
	Signature = {
		:name => "Hello World",
		:description => %{A 'hello world' applet.},
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'templated',
		:templates => {
			:templated		=> 'hello-world.tmpl',
			:printsource	=> 'hello-world-src.tmpl',
		},
	}



	######
	public
	######

	action( 'display' ) {|txn, *args|
		self.log.debug "In the 'display' action of the '%s' applet." %
			self.signature.name 

		txn.content_type = "text/plain"
		return "Hello world."
	}


	action( 'templated' ) {|txn, *args|
		self.log.debug "In the 'templated' action of the %s applet." %
			self.signature.name
			
		templ = txn.templates[:templated]
		templ.txn = txn
		templ.applet = self

		return templ
	}


	action( 'printsource' ) {|txn, *args|
		self.log.debug "In the 'printsource' action of the %s applet." %
			self.signature.name

		src = File::read( __FILE__ ).gsub(/\t/, '    ')

		templ = txn.templates[:printsource]
		templ.txn = txn
		templ.applet = self
		templ.source = src

		return templ
	}

end # class SuperHello
