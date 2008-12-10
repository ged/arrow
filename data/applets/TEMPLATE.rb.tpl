#!/usr/bin/env ruby
# 
# The (>>>class<<<) class, a derivative of Arrow::Applet. (>>>desc<<<)
# 
# == Subversion Id
# 
# $Id$
# 
# == Authors
# 
# * (>>>USER_NAME<<<) <(>>>AUTHOR<<<)>
# 

require 'arrow/applet'


### (>>>desc<<<)
class (>>>class<<<) < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Applet signature
	Signature = {
		:name => "(>>>name<<<)",
		:description => "(>>>desc<<<)",
		:maintainer => "(>>>AUTHOR<<<)",
		:default_action => 'display',
	}



	######
	public
	######

	def_action :display do |txn, *args|
		self.log.debug "In the 'display' action of the '%s' app." %
			self.signature.name 

		txn.print( "" )

		return true
	end


end # class (>>>class<<<)


>>>TEMPLATE-DEFINITION-SECTION<<<
("class" "App class: ")
("name" "App name (for the signature): ")
("desc" "Description: ")


