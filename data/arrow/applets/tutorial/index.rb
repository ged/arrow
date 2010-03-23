#!/usr/bin/env ruby
# 
# The ArrowTutorial class, a derivative of Arrow::Applet. It
# is the applet which loads and displays the tutorial (or will eventually).
# 
# == VCS Id
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


	# Applet signature
	Signature = {
		:name => "Arrow Tutorial",
		:description => "The tutorial applet.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'index',
		:templates => {
			:index => 'index.tmpl',
		},
	}


end # class ArrowTutorial


