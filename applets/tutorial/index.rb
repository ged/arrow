#!/usr/bin/ruby
# 
# This file contains the ArrowTutorial class, a derivative of Arrow::Applet. It
# is the applet which loads and displays the tutorial (or will eventually).
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


### Blah
class ArrowTutorial < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Applet signature
	Signature = {
		:name => "Arrow Tutorial",
		:description => "The tutorial applet.",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'index',
		:templates => {
			:index => 'index.tmpl',
		},
	}


end # class ArrowTutorial


