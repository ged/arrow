#!/usr/bin/env ruby/usr/bin/ruby
# 
# The ArgumentTester class, a derivative of
# Arrow::Applet. This applet is for testing/debugging/demonstrating the argument
# validator.
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/applet'


### An applet for testing/debugging the argument validator.
class ArgumentTester < Arrow::Applet

	# Applet signature
	applet_name "Argument Tester"
	applet_description "This app is for testing/debugging the argument validator."
	applet_maintainer "ged@FaerieMUD.org"

	default_action :display



	### All of the applet's functionality is handled by the default action
	### (action_missing_action), which loads the 'display' template and renders
	### it.
	template :display => 'args-display.tmpl'
    validator :display => {
		:required		=> :name,
		:optional		=> [:email, :description],
		:filters		=> [:strip, :squeeze],
		:untaint_all_constraints => true,
		:descriptions	=> {
			:email			=> "Customer Email",
			:description	=> "Issue Description",
			:name			=> "Customer Name",
		},
		:constraints	=> {
			:email	=> :email,
			:name	=> /^[\x20-\x7f]+$/,
			:description => /^[\x20-\x7f]+$/,
		},
	}

end # class ArgumentTester


