#!/usr/bin/env ruby
# 
# This file contains the RedirectorApplet class, a derivative of
# Arrow::Applet. It's only a demonstration of the Transaction's #redirect
# method.
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


### It's only a demonstration of the Transaction's #redirect method.
class RedirectorApplet < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# The default URI to redirect to
	DefaultURI = "status"


	# Applet signature
	Signature = {
		:name => "Redirector",
		:description => "It's only a demonstration of the Transaction's #redirect method.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'redirect',
	}



	######
	public
	######

	def redirect_action( txn, *args )
		self.log.debug "In the 'redirect' action of the '%s' app." %
			self.signature.name 

		uri = args.empty? ? DefaultURI : args.join("/")
		return txn.redirect( txn.app_root + "/" + uri )
	end
	alias_method :action_missing_action, :redirect_action

end # class RedirectorApplet


