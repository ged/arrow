#!/usr/bin/ruby
# 
# This file contains the ErrorHandler class, a derivative of
# Arrow::Applet. It's an example of an error-handler applet.
# 
# == Rcsid
# 
# $Id: errorHandler.rb,v 1.2 2003/11/09 19:47:29 deveiant Exp $
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

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.2 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: errorHandler.rb,v 1.2 2003/11/09 19:47:29 deveiant Exp $

	# Applet signature
	Signature = {
		:name => "Appserver Error Handler",
		:description => "Displays errors which occur in other applets in a "\
			"readable fashion. Cannot be called directly; it is used internally "\
			"by the appserver to handle errors which happen in applets.",
		:uri => "_errorHandler",
		:maintainer => "ged@FaerieMUD.org",
		:version => Version,
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

	action( 'default' ) {|txn, uri, re, err|
		self.log.debug "Loading 'display' template"
		template = txn.templates[:display]
		self.log.debug "'display' template: %p" % template

		template.re = re
		template.txn = txn
		template.err = err

		txn.print( template )

		return true
	}


	#########
	protected
	#########


end # class ErrorHandler
