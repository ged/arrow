#!/usr/bin/ruby
# 
# This file contains the Arrow::NoSuchApplet class, a derivative of
# Arrow::Applet. It is an example 'noSuchAppletHandler' applet.
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


### An example noSuchAppletHandler applet.
class Arrow::NoSuchAppletHandler < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Applet signature
	Signature = {
		:name => "No-such-applet handler",
		:description => "An example 'noSuchAppletHandler' applet. If Arrow is configured " +
						"with the uri of this applet as the noSuchAppletHandler value, " +
						"it will run this applet instead of declining requests for " +
						"URIs that don't match a registered applet.",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'display',
		:templates => {
			:display	=> 'nosuchapplet.tmpl',
		},
	}

end # class Arrow::NoSuchAppletHandler


