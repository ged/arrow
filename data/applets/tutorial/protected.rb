#!/usr/bin/env ruby
# 
# The ProtectedDelegator class, a derivative of
# Arrow::Applet. It is an applet you can chain through for authentication
# purposes.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'digest/md5'

require 'arrow/applet'


### An example applet that you can chain through for simple authentication.
class ProtectedDelegator < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	Users = {
		'ged'			=> "30ff9a6c184a0fde7ac7ade1479ee19f",
		'stillflame'	=> "4a484004cef4efebf22b2f7ec9cdc439",
	}

	# Applet signature
	Signature = {
		:name => "Password-protected delegator",
		:description => "It is an applet you can chain through for authentication purposes.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'default',
		:templates	=> {
			:default	=> 'protected.tmpl',
			:loginform	=> 'loginform.tmpl',
			:logout		=> 'logout.tmpl',
		},
	}



	######
	public
	######

	def delegate( txn, chain, *args )
		self.log.debug "Checking authentication for the %s applet." % args[0]

		if !txn.session.key?( :user )
			rval = self.run( txn, 'loginform', *args )
			unless rval == true
				return rval
			end
		end

		yield( chain )
	end


	def_action :logout do |txn, *args|
		txn.session.delete( :user )

		templ = self.load_template( :logout )
		templ.txn = txn

		return templ
	end

	def_action :loginform do |txn, *args|
		self.log.debug "In the 'display' action of the '%s' applet." %
			self.signature.name 

		username = txn.request.param('username')
		password = txn.request.param('password')
		errors = []

		if username
			pwhash = Digest::MD5.hexdigest( password )
			if !password
				errors << "No password given."
			elsif Users[ username ] != pwhash
				self.log.error "Auth failure: %p vs %p" %
					[ Users[username], pwhash ]
				errors << "Authentication failure."
			else
				txn.session[:user] = username
				return true
			end
		end

		templ = self.load_template( :loginform )
		templ.txn = txn
		templ.errors = errors unless errors.empty?

		return templ
	end


end # class ProtectedDelegator


