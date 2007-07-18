#!/usr/bin/env ruby

require 'arrow/applet'


### An Arrow appserver status applet.
class Setup < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Applet signature
	Signature = {
		:name => "Application Setup",
		:description => "Some setup task (for testing only).",
		:maintainer => "ged@FaerieMUD.org",
	}

end # class Setup


