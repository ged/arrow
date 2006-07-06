#!/usr/bin/ruby
# 
# This file contains the BlueClothDingus class, a derivative of
# Arrow::Applet. It presents a text box into which one can input Markdown text,
# which when submitted will be transformed into HTML via the BlueCloth library
# and displayed.
# 
# == Subversion ID
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/applet'
require 'bluecloth'


### It presents a text box into which
class BlueClothDingus < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Applet signature
	Signature = {
		:name => "BlueCloth Dingus",
		:description => "It presents a text box into which one can input " \
			"Markdown text, which when submitted will be transformed into " \
			"HTML via the BlueCloth library and displayed.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'display',
		:templates => {
			:display => 'dingus.tmpl',
		},
		:validator_profiles => {
			:display => {
				:required	=> :source,
				:constraints	=> {
					:source	=> /^[\x20-\x7f\r\n]+$/,
				},
			},

		}
	}



	######
	public
	######

	def_action :display do |txn, *args|
		templ = self.load_template( :display )

		if (( source = txn.vargs.valid["source"] ))
			self.log.debug "Got valid source argument: %s" % source
			templ.source = source
			templ.output = BlueCloth.new( source ).to_html
		else
			self.log.debug "No valid source argument: %p" % txn.vargs
		end

		templ.txn = txn
		templ.app = self
		templ.bcmod = BlueCloth

		return templ
	end


end # class BlueClothDingus

