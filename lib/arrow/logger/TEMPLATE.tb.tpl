#!/usr/bin/ruby
# 
# This file contains the Arrow::Logger::(>>>class<<<) class, a derivative of
# (>>>superclass<<<). (>>>description<<<)
# 
# == Rcsid
# 
# $Id: TEMPLATE.tb.tpl,v 1.1 2003/08/13 12:45:13 deveiant Exp $
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
class Logger

	### (>>>description<<<).
	class (>>>class<<<) < (>>>superclass<<<)

			# CVS version tag
			Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

			# CVS id tag
			Rcsid = %q$Id: TEMPLATE.tb.tpl,v 1.1 2003/08/13 12:45:13 deveiant Exp $


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

end # class Logger
end # module Arrow


>>>TEMPLATE-DEFINITION-SECTION<<<
("class" "Class: Arrow::Logger::")
("superclass" "Derives from: ")
("description" "File/class description: ")


