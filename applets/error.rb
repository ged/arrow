#!/usr/bin/ruby
# 
# This file contains the ErrorDemo class, a derivative of
# Arrow::Applet. This applet raises an exception to demonstrate Arrow's
# error-handling.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'arrow/applet'


### A demo applet to trigger Arrow's error-handler.
class ErrorDemo < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Applet signature
	Signature = {
		:name => "Appserver Error Handler Demo",
		:description => "Intentionally raises an exception to demonstrate "\
			"Arrow's error-handler.",
		:maintainer => "ged@FaerieMUD.org",
		:version => SVNRev,
		:config => {},
		:templates => {},
		:vargs => {},
		:monitors => {},
		:defaultAction => 'raiseAnException',
	}



	######
	public
	######

	action( 'raiseAnException' ) {|txn, *args|
		intentional_undefined_local_variable_or_method
		return true
	}


	#########
	protected
	#########


end # class ErrorDemo


