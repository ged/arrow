#!/usr/bin/env ruby
# 
# The LoadedFiles class, a derivative of Arrow::Applet. It
# displays the disposition of all the files that are being monitored by Arrow.
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


### It displays the disposition
class LoadedFiles < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Applet signature
	Signature = {
		:name => "FileMap",
		:description => "It displays the disposition of all the file that are" +
			" being monitored by Arrow.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'filemap',
		:templates => {
			:filemap => 'filemap.tmpl',
		}
	}



	######
	public
	######

	def_action :filemap do |txn, *args|
		templ = self.load_template( :filemap )
		templ.txn = txn

		return templ
	end


end # class LoadedFiles


