#!/usr/bin/ruby
# 
# This file contains the (>>>class<<<) class, a derivative of Arrow::Applet. (>>>desc<<<)
# 
# == Subversion Id
# 
# $Id$
# 
# == Authors
# 
# * (>>>USER_NAME<<<) <(>>>AUTHOR<<<)>
# 

require 'arrow/applet'


### (>>>desc<<<)
class (>>>class<<<) < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Applet signature
	Signature = {
		:name => "(>>>name<<<)",
		:description => "(>>>desc<<<)",
		:maintainer => "(>>>AUTHOR<<<)",
		:defaultAction => 'display',
	}



	######
	public
	######

	action( 'display' ) {|txn, *args|
		self.log.debug "In the 'display' action of the '%s' app." %
			self.signature.name 

		txn.print( "" )

		return true
	}


end # class (>>>class<<<)


>>>TEMPLATE-DEFINITION-SECTION<<<
("class" "App class: ")
("name" "App name (for the signature): ")
("desc" "Description: ")


