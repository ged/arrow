#!/usr/bin/ruby
# 
# This file contains the Hello class, a derivative of Arrow::Applet. It's a
# modified version of the 'Hello World' applet to illustrate how applet chaining
# works.
# 
# == Rcsid
# 
# $Id: protected-hello.rb,v 1.1 2003/12/05 00:38:15 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/applet'


### An Arrow appserver status applet.
class ProtectedHello < Arrow::Applet

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: protected-hello.rb,v 1.1 2003/12/05 00:38:15 deveiant Exp $

	# Applet signature
	Signature = {
		:name => "Hello World (Protected)",
		:description => %{A modified 'hello world' applet to illustrate how applet-chaining works.},
		:uri => "protected/hello",
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
		txn.print( "Hello world." )

		return true
	}


	action( 'templated' ) {|txn, *args|
		self.log.debug "In the 'templated' action of the %s applet." %
			self.signature.name
			
		templ = txn.templates[:templated]
		templ.txn = txn
		templ.applet = self
		
		txn.print( templ )
		return true
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

end # class ProtectedHello


