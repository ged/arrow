#!/usr/bin/ruby
# 
# This file contains the Arrow::(>>>class<<<) class, a derivative of
# (>>>superclass<<<). (>>>description<<<)
# 
# == Rcsid
# 
# $Id$
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

(>>>MARK<<<)

module Arrow

	### (>>>description<<<).
	class (>>>class<<<) < (>>>superclass<<<)

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

		# CVS id tag
		Rcsid = %q$Id$


		### Create a new Arrow::(>>>class<<<) object.
		def initialize
		end


		######
		public
		######


		#########
		protected
		#########


	end # class (>>>class<<<)

end # module Arrow


>>>TEMPLATE-DEFINITION-SECTION<<<
("class" "Class: Arrow:: ")
("superclass" "Derives from: ")
("description" "File/class description: ")


