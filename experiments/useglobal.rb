#
# Testing out someone's problems with seeing globals in mod_ruby (from 
# #ruby-lang)
#

### In 'useglobal.rb':

require 'globaldef'

class GlobalUser
	def handler( req )
		req.content_type = "text/plain"
		req.print $a_global
		
		return Apache::OK
	end
end

# ### In 'globaldef.rb':
# 
# $a_global = "It worked"
# 
# ### In httpd.conf:
# 
# RubyRequire useglobal
# 
# <Location /global>
#   SetHandler ruby-object
#   RubyHandler GlobalUser.new
# </Location>
# 
