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

	# SVN URL
	SVNURL = %q$URL$

	# Applet signature
	Signature = {
		:name => "BlueCloth Dingus",
		:description => "It presents a text box into which one can input " \
			"Markdown text, which when submitted will be transformed into " \
			"HTML via the BlueCloth library and displayed.",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'display',
		:templates => {
			:display => 'dingus.tmpl',
		},
		:validatorProfiles => {
			:display => {
				:required	=> :source,
				:filters	=> [:strip],
				:constraints	=> {
					:source	=> /^[\x20-\x7f]+$/,
				},
			},
		}
	}



	######
	public
	######

	action( 'display' ) {|txn, *args|
		templ = txn.templates[:display]

		if (( source = txn.vargs.valid[:source] ))
			templ.source = BlueCloth::new( source )
			templ.output = source.to_html
		end

		return templ
	}


end # class BlueClothDingus


