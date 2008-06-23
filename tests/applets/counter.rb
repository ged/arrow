#!/usr/bin/env ruby
# 
# This file contains the AccessCounter class, a derivative of
# Arrow::Applet. It's a little applet for testing session persistance. It just
# increments and displays a counter which is held in a session object.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the BASE directory for licensing details.
#

require 'arrow/applet'


### An applet for testing session persistance and applet-chaining.
class AccessCounter < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Applet signature
	Signature = {
		:name => "Session Access Counter",
		:description => "Increments and displays a counter contained in a session object.",
		:maintainer => "ged@FaerieMUD.org",
		:config => {},
		:templates => {
			:counter	=> 'counter.tmpl',
			:deleted	=> 'counter-deleted.tmpl',
		},
		:vargs => {},
		:monitors => {},
		:default_action => 'display',
	}



	######
	public
	######

	### When called as a chained applet, just increment two session counters and
	### hand off control to the next applet in the chain.
	def delegate( txn, chain, *args )
		begin
			# Set up and increment this app's execution counter
			txn.session[:counter] ||= 0
			txn.session[:counter] += 1
			
			# Set up and increment the delegation counter
			txn.session[:delegations] ||= 0
			txn.session[:delegations] += 1
		rescue ::Exception => err
			self.log.error "Error while setting up session: #{err.message}"
		end

		yield( chain )
	end


	### The 'display' (default) action. Increments and displays the counter.
	def_action :display do |txn, *args|
		self.log.debug "In the 'display' action of the '%s' applet." %
			self.signature.name 

		templ = self.load_template( :counter )
		txn.session[:counter] ||= 0
		txn.session[:counter] += 1

		txn.session[:lastChild] = Process.pid

		templ.session = txn.session
		templ.txn = txn

		txn.print( templ )

		return true
	end

	### Deletes the session
	def_action :delete do |txn, *args|
		self.log.debug "In the 'delete' action of the '%s' applet." %
			self.signature.name 

		templ = self.load_template( :deleted )
		txn.session.remove

		templ.txn = txn
		txn.print( templ )

		return true
	end


end # class AccessCounter


