#!/usr/bin/env ruby
# 
# The ConfigApplet class, a derivative of Arrow::Applet. It
# can be used to view/edit Arrow configurations.
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
require 'arrow/config'


### An Arrow applet class for viewing/editing Arrow configurations.
class ConfigApplet < Arrow::Applet

	# Applet signature
	Signature = {
		:name => "ConfigApplet",
		:description => "view/edit Arrow configuration",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'display',
		:templates => {
			:display	=> 'config/display.tmpl',
			:display_table => 'config/display-table.tmpl',
		},
	}



	######
	public
	######

	def display_action( txn, *args )
		templ = self.load_template( :display )

		templ.txn = txn
		templ.applet = self
		templ.config = @config

		return templ
	end




end # class ConfigApplet


