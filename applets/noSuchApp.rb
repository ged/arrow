#!/usr/bin/ruby
# 
# This file contains the NoSuchApplet class, a derivative of Arrow::Applet. It
# is an example noSuchAppletHandler applet.
# 
# == Rcsid
# 
# $Id: noSuchApplet.rb,v 1.2 2004/02/14 03:23:17 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/applet'


### An example noSuchAppletHandler applet.
class NoSuchAppletHandle < Arrow::Applet

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.2 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: noSuchApplet.rb,v 1.2 2004/02/14 03:23:17 deveiant Exp $

	# Applet signature
	Signature = {
		:name => "No-such-applet handler",
		:description => "An example 'noSuchAppletHandler' applet. If Arrow is configured " +
						"with the uri of this applet as the noSuchAppletHandler value, " +
						"it will run this applet instead of declining requests for " +
						"URIs that don't match a registered applet.",
		:uri => "_nosuch",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'display',
		:templates => {
			:display	=> 'nosuchapplet.tmpl',
		},
	}



	######
	public
	######


end # class NoSuchAppletHandler


