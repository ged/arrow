#!/usr/bin/ruby
# 
# This file contains the Args class, a derivative of Arrow::Application. This
# app is for testing/debugging the argument validator.
# 
# == Rcsid
# 
# $Id: args.rb,v 1.1 2004/01/27 06:46:41 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/application'


### An Arrow appserver status application.
class Args < Arrow::Application

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: args.rb,v 1.1 2004/01/27 06:46:41 deveiant Exp $

	# Application signature
	Signature = {
		:name => "Argument Tester",
		:description => "This app is for testing/debugging the argument validator.",
		:uri => "args",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'display',
		:templates => {
			:display	=> 'args-display.tmpl',
		},
		:vargs => {
			:display	=> {
				:required		=> :name,
				:optional		=> [:email, :description],
				:filters		=> [:strip, :squeeze],
				:constraints	=> {
					:email	=> :email,
					:name	=> /^[\x20-\x7f]+$/,
					:description => /^[\x20-\x7f]+$/,
				},
			},
		},
	}

end # class Status


