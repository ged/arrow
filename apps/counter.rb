#!/usr/bin/ruby
# 
# This file contains the Counter class, a derivative of Arrow::Application. It's
# a little app for testing session persistance. It just increments and displays
# a counter which is held in a session object.
# 
# == Rcsid
# 
# $Id: counter.rb,v 1.3 2003/12/05 00:39:10 deveiant Exp $
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
class Counter < Arrow::Application

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.3 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: counter.rb,v 1.3 2003/12/05 00:39:10 deveiant Exp $

	# Application signature
	Signature = {
		:name => "Session Access Counter",
		:description => "Increments and displays a counter contained in a session object.",
		:uri => "counter",
		:maintainer => "ged@FaerieMUD.org",
		:version => Version,
		:config => {},
		:templates => {
			:counter	=> 'counter.tmpl',
			:deleted	=> 'counter-deleted.tmpl',
		},
		:vargs => {},
		:monitors => {},
		:defaultAction => 'display',
	}



	######
	public
	######

	### When called as a chained app, just increment two session counters and
	### hand off control to the next app in the chain.
	def delegate( txn, *args )
		txn.session[:counter] ||= 0
		txn.session[:counter] += 1

		txn.session[:delegations] ||= 0
		txn.session[:delegations] += 1

		yield
	end


	### The 'display' (default) action. Increments and displays the counter.
	action( 'display' ) {|txn, *args|
		self.log.debug "In the 'display' action of the '%s' app." %
			self.signature.name 

		templ = txn.templates[:counter]
		txn.session[:counter] ||= 0
		txn.session[:counter] += 1

		txn.session[:lastChild] = Process::pid

		templ.session = txn.session
		templ.txn = txn

		txn.print( templ )

		return true
	}

	### Deletes the session
	action( 'delete' ) {|txn, *args|
		self.log.debug "In the 'display' action of the '%s' app." %
			self.signature.name 

		templ = txn.templates[:deleted]
		txn.session.remove

		templ.txn = txn
		txn.print( templ )

		return true
	}


end # class Status


