#!/usr/bin/ruby
# 
# This file contains the ServerStatus class, a derivative of Arrow::Applet. An
# appserver status applet.
# 
# == Subversion Id
#
#  $Id$
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
class ServerStatus < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Applet signature
	Signature = {
		:name => "Appserver Status",
		:description => "Displays a list of all loaded applets or information " +
			"about a particular one.",
		:maintainer => "ged@FaerieMUD.org",
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

		templ = self.loadTemplate( :status )
		templ.registry = txn.broker.registry
		templ.transaction = txn
		templ.txn = txn
		templ.pid = Process::pid
		templ.ppid = Process::ppid
		templ.currentApplet = self

		self.log.debug "About to return from the 'display' action."
		return templ
	}


	action( 'applet' ) {|txn, *args|
		self.log.debug "In the 'applet' action of the '%s' applet." %
			self.signature.name

		re = txn.broker.registry[ args.join("/") ]
		if re.nil?
			self.log.error "%s: no such applet to inspect. Registry contains: %p" % 
				[ args[0], txn.broker.registry.keys.sort ]
			return self.run( txn, 'display' )
		end

		targetapp = re.object

		templ = self.loadTemplate( :applet )
		templ.uri = args.join("/")
		templ.applet = targetapp
		templ.re = re
		templ.txn = txn
		templ.pid = Process::pid
		templ.ppid = Process::ppid
		templ.currentApplet = self
		
		return templ
	}


end # class ServerStatus


