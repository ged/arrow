#!/usr/bin/ruby
# 
# This file contains the MissingApplet class, a derivative of Arrow::Applet. It
# is an example 'missingApplet' applet.
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
class MissingApplet < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev: 54 $

	# SVN Id
	SVNId = %q$Id: noSuchApp.rb 54 2004-05-22 06:42:56Z deveiant $


	# Applet signature
	Signature = {
		:name => "No-such-applet handler",
		:description => "An example 'missingApplet' applet. If Arrow is configured " +
						"with the uri of this applet as the missingApplet value, " +
						"it will run this applet instead of declining requests for " +
						"URIs that don't match a registered applet.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'display',
		:templates => {
			:display	=> 'missingapplet.tmpl',
		},
	}

	# No action: defaults to loading and displaying the template with the same
	# name as the action.

end # class NoSuchAppletHandler


