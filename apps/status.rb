#!/usr/bin/ruby
# 
# This file contains the Status class, a derivative of Arrow::Application. An
# appserver status application.
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

require 'arrow/application'


### An Arrow appserver status application.
class Status < Arrow::Application

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.5 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: status.rb,v 1.5 2003/12/05 01:02:35 deveiant Exp $

	# Application signature
	Signature = {
		:name => "Appserver Status",
		:description => "Displays the internal status of the appserver.",
		:uri => "status",
		:maintainer => "ged@FaerieMUD.org",
		:version => Version,
		:config => {},
		:templates => {
			:status	=> 'status.tmpl',
			:app	=> 'app-status.tmpl',
		},
		:vargs => {},
		:monitors => {},
		:defaultAction => 'display',
	}


	######
	public
	######

	action( 'display' ) {|txn, *args|
		self.log.debug "In the 'display' action of the '%s' app." %
			self.signature.name 

		templ = txn.templates[:status]
		templ.apps = txn.broker.registry.collect {|uri, re| re.object }
		templ.transaction = txn
		templ.pid = Process::pid
		templ.ppid = Process::ppid
		templ.currentApp = self

		return templ
	}


	action( 'app' ) {|txn, *args|
		self.log.debug "In the 'app' action of the '%s' app." %
			self.signature.name

		targetapp = txn.broker.registry[ args.join("/") ]
		if targetapp.nil?
			self.log.info "%s: no such app to inspect. Registry contains: %p" % 
				[ args[0], txn.broker.registry.keys.sort ]
			return self.run( txn, 'display' )
		end

		templ = txn.templates[:app]
		templ.app = targetapp
		templ.txn = txn
		templ.currentApp = self
		
		return templ
	}

	#########
	protected
	#########


end # class Status


