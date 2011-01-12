#!/usr/bin/env ruby
# 
# The MissingApplet class, a derivative of Arrow::Applet. It
# is an example 'missingApplet' applet.
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/applet'


### An example missingApplet applet.
class MissingApplet < Arrow::Applet


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


