#!/usr/bin/ruby
# 
# This file contains the LoadedFiles class, a derivative of Arrow::Applet. It
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

	# SVN URL
	SVNURL = %q$URL$

	# Applet signature
	Signature = {
		:name => "FileMap",
		:description => "It displays the disposition of all the file that are" +
			" being monitored by Arrow.",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'filemap',
		:templates => {
			:filemap => 'filemap.tmpl',
		}
	}



	######
	public
	######

	action( 'filemap' ) {|txn, *args|
		templ = self.loadTemplate( :filemap )
		templ.txn = txn

		return templ
	}


end # class LoadedFiles


