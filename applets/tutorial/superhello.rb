#!/usr/bin/env ruby
# 
# This file contains the SuperHello class, a derivative of Arrow::Applet. A
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


### A superclass applet for testing inheritance
class SuperHello < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Applet signature -- since it defines no 'uri' item, it shouldn't be loaded
	# by the appserver directly.
	Signature = {
		:name => "Hello World",
		:description => %{A 'hello world' applet.},
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'templated',
		:templates => {
			:templated		=> 'hello-world.tmpl',
			:printsource	=> 'hello-world-src.tmpl',
		},
	}



	######
	public
	######

	def_action :display do |txn, *args|
		self.log.debug "In the 'display' action of the '%s' applet." %
			self.signature.name 

		txn.content_type = "text/plain"
		return "Hello world."
	end


	def_action :templated do |txn, *args|
		self.log.debug "In the 'templated' action of the %s applet." %
			self.signature.name
			
		templ = self.load_template( :templated )
		templ.txn = txn
		templ.applet = self

		return templ
	end


	def_action :printsource do |txn, *args|
		self.log.debug "In the 'printsource' action of the %s applet." %
			self.signature.name

		src = File.read( __FILE__ ).gsub(/\t/, '    ')

		templ = self.load_template( :printsource )
		templ.txn = txn
		templ.applet = self
		templ.source = src

		return templ
	end

end # class SuperHello
