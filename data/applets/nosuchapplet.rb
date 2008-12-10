#!/usr/bin/env ruby
# 
# The NoSuchAppletHandler class, a derivative of
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


### An example missingApplet applet.
class NoSuchAppletHandler < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Applet signature
	applet_name "No-such-applet handler"
	applet_description "An example 'noSuchAppletHandler' applet. If Arrow is configured " +
						"with the uri of this applet as the noSuchAppletHandler value, " +
						"it will run this applet instead of declining requests for " +
						"URIs that don't match a registered applet."
	applet_maintainer "ged@FaerieMUD.org"
	
	default_action :display
	template :display	=> 'nosuchapplet.tmpl'

end # class NoSuchAppletHandler


