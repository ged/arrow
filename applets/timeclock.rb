#!/usr/bin/ruby
# 
# This file contains the TimeClock class, a derivative of Arrow::Applet; it
# implements a web-based timeclock applet.
# 
# == Subversion Id
#
#  $Id$
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

require 'bdb'

require 'arrow/applet'


### A timeclock applet
class TimeClock < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

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
		:defaultAction => 'home',
	}



	######
	public
	######

	### Override #run to do things that need to be done for every action. All
	### actions will be wrapped by this method, which wraps the template objects
	### they return in a container 'main' template.
	def run( txn, *rest )
		super {|meth, txn, *rest|
			template = self.loadTemplate( :main )
			
			template.body = meth.call( txn, *rest )
			template.txn = txn
			template.navbar.txn = txn

			return template
		}
	end


	### Actions
	
	# 'home' is an implicit (template-only) action


end # class TimeClock


