#!/usr/bin/ruby
# 
# This file contains the ErrorThrower class, a derivative of
# Arrow::Application. This app raises an exception to demonstrate Arrow's
# error-handling.
# 
# == Rcsid
# 
# $Id: error.rb,v 1.2 2003/11/01 19:46:01 deveiant Exp $
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
class ErrorDemo < Arrow::Application

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.2 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: error.rb,v 1.2 2003/11/01 19:46:01 deveiant Exp $

	# Application signature
	Signature = {
		:name => "Appserver Error Handler Demo",
		:description => "Intentionally raises an exception to demonstrate "\
			"Arrow's error-handler.",
		:uri => "raiseError",
		:maintainer => "ged@FaerieMUD.org",
		:version => Version,
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


end # class Status


