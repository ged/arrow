#!/usr/bin/ruby
# 
# This file contains the SuperHello class, a derivative of Arrow::Application. A
# "hello world" app.
# 
# == Rcsid
# 
# $Id: superhello.rb,v 1.1 2003/12/08 20:40:05 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/application'


### An Arrow appserver status application.
class SuperHello < Arrow::Application

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: superhello.rb,v 1.1 2003/12/08 20:40:05 deveiant Exp $

	# Application signature
	Signature = {
		:name => "Hello World",
		:description => %{A 'hello world' app.},
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
		self.log.debug "In the 'display' action of the '%s' app." %
			self.signature.name 

		txn.content_type = "text/plain"
		return "Hello world."
	}


	action( 'templated' ) {|txn, *args|
		self.log.debug "In the 'templated' action of the %s app." %
			self.signature.name
			
		templ = txn.templates[:templated]
		templ.txn = txn
		templ.app = self

		return templ
	}


	action( 'printsource' ) {|txn, *args|
		self.log.debug "In the 'printsource' action of the %s app." %
			self.signature.name

		src = File::read( __FILE__ ).gsub(/\t/, '    ')

		templ = txn.templates[:printsource]
		templ.txn = txn
		templ.app = self
		templ.source = src

		return templ
	}

end # class SuperHello
