#!/usr/bin/ruby
# 
# This file contains the HelloWorld class, a derivative of Arrow::Applet. A
# "hello world" applet.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/applet'


### A "hello world" applet.
class HelloWorld < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Applet signature
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

	def display_action( txn, *args )
		self.log.debug "In the 'display' action of the '%s' applet." %
			self.signature.name 

		txn.content_type = "text/plain"
		return "Hello world."
	end


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

end # class HelloWorld


