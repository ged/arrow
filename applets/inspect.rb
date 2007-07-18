#!/usr/bin/env ruby
# 
# This file contains the InspectorApplet class, a derivative of
# Arrow::Applet. It dumps data that might be useful to applet developers.
# 
# == Subversion Id
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/applet'


### An applet that displays introspection information that might be useful to
### applet developers.
class InspectorApplet < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Applet signature
	Signature = {
		:name => "Inspector",
		:description => "It dumps data that might be useful to applet developers.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'display',
		:templates => {
			:display => 'inspect/display.tmpl',
		},
	}


	def display_action( txn, *args )
		templ = self.load_template( :display )

		templ.txn = txn
		templ.applet = self

		return templ
	end

end # class InspectorApplet


