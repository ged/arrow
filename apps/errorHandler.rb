#!/usr/bin/ruby
# 
# This file contains the ErrorHandler class, a derivative of
# Arrow::Application. It's an example of an error-handler application.
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

require 'arrow/application'


### An Arrow appserver status application.
class ErrorHandler < Arrow::Application

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.2 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: errorHandler.rb,v 1.2 2003/11/09 19:47:29 deveiant Exp $

	# Application signature
	Signature = {
		:name => "Appserver Error Handler",
		:description => "Displays errors which occur in other applications in a "\
			"readable fashion. Cannot be called directly; it is used internally "\
			"by the appserver to handle errors which happen in applications.",
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


end # class Arrow::ErrorHandler
