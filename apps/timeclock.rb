#!/usr/bin/ruby
# 
# This file contains the TimeClock class, a derivative of Arrow::Application; it
# implements a web-based timeclock application.
# 
# == Rcsid
# 
# $Id: timeclock.rb,v 1.1 2003/12/05 00:38:15 deveiant Exp $
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
class TimeClock < Arrow::Application

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: timeclock.rb,v 1.1 2003/12/05 00:38:15 deveiant Exp $

	# Application signature
	Signature = {
		:name => "",
		:description => "A web-enabled timeclock for consultants.",
		:uri => "timeclock",
		:maintainer => "ged@FaerieMUD.org",
		:version => Version,
		:config => {
			:datasource	=> 'dbi://user:pass@localhost/mysql/timeclock',
		},
		:templates => {
			:main		=> 'timeclock/main.tmpl',
			:entry		=> 'timeclock/entry.tmpl',
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
		:defaultAction => 'entry',
	}



	######
	public
	######

	### Override #run to do things that need to be done for every action. This
	### means that all actions in this app return subordinate templates instead of
	### the status boolean.
	def run( txn, *rest )
		super {|meth, txn, *rest|
			template = txn.templates[:main]
			
			template.body = meth.call( txn, *rest )
			template.txn = txn
			template.navbar.txn = txn

			txn.print( template )

			return true
		}
	end


	### Actions
	
	action( 'entry' ) {|txn, *args|
		templ = txn.templates[:entry]
		templ.txn = txn

		return templ
	}



end # class TimeClock


