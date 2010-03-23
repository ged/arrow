#!/usr/bin/env ruby
# 
# The ServerStatus class, a derivative of Arrow::Applet. An
# appserver status applet.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#

require 'arrow/applet'


### An Arrow appserver status applet.
class ServerStatus < Arrow::Applet


	# Applet signature
	Signature = {
		:name => "Appserver Status",
		:description => "Displays a list of all loaded applets or information " +
			"about a particular one.",
		:maintainer => "ged@FaerieMUD.org",
		:config => {},
		:templates => {
			:status	=> 'status.tmpl',
			:applet	=> 'applet-status.tmpl',
		},
		:vargs => {},
		:monitors => {},
		:default_action => 'display',
	}


	######
	public
	######

	def_action :display do |txn, *args|
		self.log.debug "In the 'display' action of the '%s' applet." %
			self.signature.name 

		templ = self.load_template( :status )
		templ.registry = txn.broker.registry
		templ.transaction = txn
		templ.txn = txn
		templ.pid = Process.pid
		templ.ppid = Process.ppid
		templ.currentApplet = self

		self.log.debug "About to return from the 'display' action."
		return templ
	end


	def_action :applet do |txn, *args|
		self.log.debug "In the 'applet' action of the '%s' applet." %
			self.signature.name

		applet = txn.broker.registry[ args.join("/") ]
		if applet.nil?
			self.log.error "%s: no such applet to inspect. Registry contains: %p" % 
				[ args[0], txn.broker.registry.keys.sort ]
			return self.run( txn, 'display' )
		end

		templ = self.load_template( :applet )
		templ.uri = args.join("/")
		templ.applet = applet
		templ.txn = txn
		templ.pid = Process.pid
		templ.ppid = Process.ppid
		templ.currentApplet = self
		
		return templ
	end


	def decline_action( txn, *args )
		return nil
	end

	alias_method :css_action, :decline_action
	alias_method :images_action, :decline_action
	alias_method :js_action, :decline_action
	alias_method :javascript_action, :decline_action

end # class ServerStatus


