#!/usr/bin/ruby
# 
# This file contains the ArgumentTester class, a derivative of
# Arrow::Applet. This applet is for testing/debugging/demonstrating the argument
# validator.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/applet'


### An applet for testing/debugging the argument validator.
class ArgumentTester < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Applet signature
	Signature = {
		:name => "Argument Tester",
		:description => "This app is for testing/debugging the argument validator.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'display',
		:templates => {
			:display	=> 'args-display.tmpl',
		},
		:vargs => {
			:display	=> {
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
			},
		},
	}

	### All of the applet's functionality is handled by the default action
	### (action_missing_action), which loads the 'display' template and renders
	### it.

end # class ArgumentTester


