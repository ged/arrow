#!/usr/bin/ruby

require 'arrow/applet'


### An Arrow appserver status applet.
class Setup < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev: 169 $

	# SVN Id
	SVNId = %q$Id: status.rb 169 2004-08-21 05:39:00Z ged $

	# SVN URL
	SVNURL = %q$URL: svn+ssh://svn.FaerieMUD.org/usr/local/svn/Arrow/trunk/applets/status.rb $

	# Applet signature
	Signature = {
		:name => "Application Setup",
		:description => "Some setup task (for testing only).",
		:maintainer => "ged@FaerieMUD.org",
	}

end # class Setup


