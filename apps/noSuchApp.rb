#!/usr/bin/ruby
# 
# This file contains the NoSuchApp class, a derivative of Arrow::Application. It
# is an example noSuchApp handler.
# 
# == Rcsid
# 
# $Id: noSuchApp.rb,v 1.2 2004/02/14 03:23:17 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/application'


### An Arrow appserver status application.
class NoSuchApp < Arrow::Application

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.2 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: noSuchApp.rb,v 1.2 2004/02/14 03:23:17 deveiant Exp $

	# Application signature
	Signature = {
		:name => "No-such-app handler",
		:description => "An example 'noSuchAppHandler' application. If Arrow is configured " +
						"with the uri of this app as the noSuchAppHandler value, " +
						"it will run this app instead of declining requests for " +
						"URIs that don't match a registered application.",
		:uri => "_nosuch",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'display',
		:templates => {
			:display	=> 'nosuchapp.tmpl',
		},
	}



	######
	public
	######


end # class Status


