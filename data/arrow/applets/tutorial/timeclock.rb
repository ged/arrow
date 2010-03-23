#!/usr/bin/env ruby
# 
# The TimeClock class, a derivative of Arrow::Applet; it
# implements a web-based timeclock applet.
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#

require 'bdb'

require 'arrow/applet'


### A timeclock applet
class TimeClock < Arrow::Applet


	# Applet signature
	Signature = {
		:name => "",
		:description => "A web-enabled timeclock for consultants.",
		:uri => "timeclock",
		:maintainer => "ged@FaerieMUD.org",
		:version => SVNRev,
		:config => {
			:datadir	=> '/www/RubyCrafters.com/private/timeclock',
		},
		:templates => {
			:main		=> 'timeclock/main.tmpl',
			:home		=> 'timeclock/home.tmpl',
		},
		:vargs => {
			:_default_ => {
				:optional		=> [:username],
				:constraints	=> {
					:username	=> /^(\w+)$/,
				},
				:untaint_constraint_fields => %w{class inline},
			},
		},
		:monitors => {},
		:default_action => 'home',
	}



	######
	public
	######

	### Override #run to do things that need to be done for every action. All
	### actions will be wrapped by this method, which wraps the template objects
	### they return in a container 'main' template.
	def run( txn, *rest )
		super {|meth, txn, *rest|
			template = self.load_template( :main )
			
			template.body = meth.call( txn, *rest )
			template.txn = txn
			template.navbar.txn = txn

			return template
		}
	end


	### Actions
	
	# 'home' is an implicit (template-only) action


end # class TimeClock


