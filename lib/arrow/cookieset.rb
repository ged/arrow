#!/usr/bin/env ruby
# 
# An object which provides a convenient way of accessing a set of Arrow::Cookies.
# 
# == Synopsis
# 
#   cset = Arrow::CookieSet.new()
#   cset = Arrow::CookieSet.new( cookies )
#
#   cset['cookiename']  # => Arrow::Cookie
#
#   cset['cookiename'] = cookie_object
#   cset['cookiename'] = 'cookievalue'
#   cset[:cookiename] = 'cookievalue'
#   cset << Arrow::Cookie.new( *args )
#
#   cset.include?( 'cookiename' )
#   cset.include?( cookie_object )
#
#   cset.each do |cookie|
#      ...
#   end
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# * Jeremiah Jordan <phaedrus@FaerieMUD.org>
# 
# :include: COPYRIGHT
# 
# ---
# 
# Please see the file docs/COPYRIGHT for licensing details.
# 

require 'arrow'
require 'arrow/cookie'
require 'set'
require 'forwardable'


### An object class which provides convenience functions for accessing a set of 
### Arrow::Cookie objects.
class Arrow::CookieSet < Arrow::Object
	extend Forwardable
	include Enumerable


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new CookieSet prepopulated with the given cookies
	def initialize( *cookies )
		@cookie_set = Set.new( cookies.flatten )
	end


	######
	public
	######

	def_delegators :@cookie_set, :each
	
	
	### Returns the number of cookies in the cookieset
	def length
		return @cookie_set.length
	end
	alias_method :size, :length


	### Index operator method: returns the Arrow::Cookie with the given +name+ if it 
	### exists in the cookieset.
	def []( name )
		name = name.to_s
		return @cookie_set.find() {|cookie| cookie.name == name }
	end


	### Index set operator method: set the cookie that corresponds to the given +name+
	### to +value+. If +value+ is not an Arrow::Cookie, one with be created and its
	### value set to +value+.
	def []=( name, value )
		value = Arrow::Cookie.new( name.to_s, value ) unless value.is_a?( Arrow::Cookie )
		raise ArgumentError, "cannot set a cookie named '%s' with a key of '%s'" %
			[ value.name, name ] if value.name.to_s != name.to_s

		self << value
	end
	

	### Returns +true+ if the CookieSet includes either a cookie with the given name or
	### an Arrow::Cookie object.
	def include?( name_or_cookie )
		return true if @cookie_set.include?( name_or_cookie )
		name = name_or_cookie.to_s
		return self[name] ? true : false
	end
	alias_method :key?, :include?


	### Append operator: Add the given +cookie+ to the set, replacing an existing
	### cookie with the same name if one exists.
	def <<( cookie )
		@cookie_set.delete( cookie )
		@cookie_set.add( cookie )
		
		return self
	end


end # class Arrow::CookieSet

