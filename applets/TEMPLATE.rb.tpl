#!/usr/bin/ruby
# 
# This file contains the (>>>class<<<) class, a derivative of Arrow::Applet. (>>>desc<<<)
# 
# == Rcsid
# 
# $Id: TEMPLATE.rb.tpl,v 1.1 2003/11/01 19:42:05 deveiant Exp $
# 
# == Authors
# 
# * (>>>USER_NAME<<<) <(>>>AUTHOR<<<)>
# 

require 'arrow/applet'


### (>>>desc<<<)
class (>>>class<<<) < Arrow::Applet

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: TEMPLATE.rb.tpl,v 1.1 2003/11/01 19:42:05 deveiant Exp $

	# Applet signature
	Signature = {
		:name => "(>>>name<<<)",
		:description => "(>>>desc<<<)",
		:maintainer => "(>>>AUTHOR<<<)",
		:defaultAction => 'display',
	}



	######
	public
	######

	action( 'display' ) {|txn, *args|
		self.log.debug "In the 'display' action of the '%s' app." %
			self.signature.name 

		txn.print( "" )

		return true
	}


end # class (>>>class<<<)


>>>TEMPLATE-DEFINITION-SECTION<<<
("class" "App class: ")
("name" "App name (for the signature): ")
("desc" "Description: ")


