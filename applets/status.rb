#!/usr/bin/ruby
# 
# This file contains the Status class, a derivative of Arrow::Applet. An
# appserver status applet.
# 
# == Rcsid
# 
# $Id: status.rb,v 1.5 2003/12/05 01:02:35 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'arrow/applet'


### An Arrow appserver status applet.
class Status < Arrow::Applet

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.5 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: status.rb,v 1.5 2003/12/05 01:02:35 deveiant Exp $

	# Applet signature
	Signature = {
		:name => "Appserver Status",
		:description => "Displays a list of all loaded applets or information " +
			"about a particular one.",
		:uri => "status",
		:maintainer => "ged@FaerieMUD.org",
		:version => Version,
		:config => {},
		:templates => {
			:status	=> 'status.tmpl',
			:applet	=> 'applet-status.tmpl',
		},
		:vargs => {},
		:monitors => {},
		:defaultAction => 'display',
	}


	######
	public
	######

	action( 'display' ) {|txn, *args|
		self.log.debug "In the 'display' action of the '%s' applet." %
			self.signature.name 

		templ = txn.templates[:status]
		templ.applets = txn.broker.registry.collect {|uri, re| re.object }
		templ.transaction = txn
		templ.pid = Process::pid
		templ.ppid = Process::ppid
		templ.currentApplet = self

		return templ
	}


	action( 'applet' ) {|txn, *args|
		self.log.debug "In the 'applet' action of the '%s' applet." %
			self.signature.name

		targetapp = txn.broker.registry[ args.join("/") ]
		if targetapp.nil?
			self.log.info "%s: no such applet to inspect. Registry contains: %p" % 
				[ args[0], txn.broker.registry.keys.sort ]
			return self.run( txn, 'display' )
		end

		templ = txn.templates[:applet]
		templ.applet = targetapp
		templ.txn = txn
		templ.currentApplet = self
		
		return templ
	}


end # class Status


