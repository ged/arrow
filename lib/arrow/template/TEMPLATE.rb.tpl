#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::(>>>class<<<) class, a derivative of
# Arrow::Template::(>>>superclass<<<). This is the class which defines the
# behaviour of the '(>>>directive<<<)' template directive.
#
# == Syntax
#
#	(>>>POINT<<<)
#
# == Subversion Id
# 
# $Id: TEMPLATE.rb.tpl,v 1.1 2003/08/13 12:42:57 deveiant Exp $
# 
# == Authors
# 
# * (>>>USER_NAME<<<) <(>>>AUTHOR<<<)>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'arrow/exceptions'
require 'arrow/utils'
require 'arrow/template/nodes'

module Arrow
class Template

	### The class which defines the behaviour of the '(>>>directive<<<)'
	### template directive.
	class (>>>class<<<) < Arrow::Template::(>>>superclass<<<)

		# SVN Revision
		SVNRev = %q$Rev: 183 $
		
		# SVN Id
		SVNId = %q$Id: import.rb 183 2004-08-23 06:10:32Z ged $
		
		# SVN URL
		SVNURL = %q$URL: svn+ssh://svn.FaerieMUD.org/usr/local/svn/Arrow/trunk/lib/arrow/template/import.rb $

		(>>>MARK<<<)

	end # class (>>>class<<<)

end # class Template
end # module Arrow


>>>TEMPLATE-DEFINITION-SECTION<<<
("class" "Class: Arrow::Template::")
("superclass" "Derives from: Arrow::Template::")
("directive" "Which directive does this class implement: ")


