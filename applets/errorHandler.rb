#!/usr/bin/ruby
# 
# This file contains the ErrorHandler class, a derivative of
# Arrow::Applet. It's an example of an error-handler applet.
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


### An error-handling applet.
class ErrorHandler < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Applet signature
	Signature = {
		:name => "Appserver Error Handler",
		:description => "Displays errors which occur in other applets in a "\
			"readable fashion. Cannot be called directly; it is used internally "\
			"by the appserver to handle errors which happen in applets.",
		:maintainer => "ged@FaerieMUD.org",
		:version => SVNRev,
		:config => {},
		:templates => {
			:display	=> 'error-display.tmpl',
		},
		:vargs => {},
		:monitors => {},
		:defaultAction => 'default',
	}



	######
	public
	######

	action( 'default' ) {|*args|
		intentional_undefined_local_variable_or_method
		return "Hmmm... that didn't work"
	}

	def report_error_action( txn, re, err )
		self.log.debug "Loading 'display' template"
		template = txn.templates[:display]
		self.log.debug "'display' template: %p" % template

		template.re = re
		template.txn = txn
		template.err = err

		txn.print( template )

		return true
	end
	

	#########
	protected
	#########


end # class ErrorHandler
