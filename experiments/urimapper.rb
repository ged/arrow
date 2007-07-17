#!/usr/bin/ruby
#
# Find a good algorithm for mapping the URI path onto a registry of applets
# 

BEGIN {
	require 'pathname'
	base = Pathname.new( __FILE__ ).expand_path.dirname.parent
	libdir = base + 'lib'

	$LOAD_PATH.unshift( libdir )

	require base + 'utils.rb'
	include UtilityFunctions
}

require 'arrow/applet'

class AccessControl < Arrow::Applet; end
class ServiceController < Arrow::Applet; def api_action(*args); end; end
class UserService < Arrow::Applet; end
class GroupService < Arrow::Applet; def user_action(*args); end; end
class EntryService < Arrow::Applet; end


Registry = {
	''                 => AccessControl.new(nil, nil, nil),
	'/service'         => ServiceController.new(nil, nil, nil),
	'/service/users'   => UserService.new(nil, nil, nil),
	'/service/groups'  => GroupService.new(nil, nil, nil),
	'/service/entries' => EntryService.new(nil, nil, nil),
}

URIs = %w[
	/
	/service
	/service/api
	/service/api.wadl
	/service/api/v2.wadl
	/service/api.v2.wadl
	/service/api/wadl
	/service/api/wadl/v2
	/service/users
	/service/users.xml
	/service/users.js
	/service/groups/user/mgranger@laika.com
]

PARTIAL_IDENTIFIER = /^[a-z]\w+/i
IDENTIFIER = /#{PARTIAL_IDENTIFIER}$/



def map_uri( uri )
	# partition the uri into two arrays: mappable parts, and argument parts. The 
	# argument parts begin at the first part of the uri that isn't an identifier
	saw_arg = false
	args, uri_parts = uri.split(%r{/}).
		partition {|item| saw_arg || saw_arg = (item !~ IDENTIFIER)}

	# There must be at least one uri part
	uri_parts << '' if uri_parts.empty?

	chain = []
	debugMsg "URI parts are: %p, args are: %p" % [uri_parts, args]
	
	uri_parts.each_index do |i|
		appleturi = nil

		debugMsg "Mapping part %d: %p" % [i, uri_parts[i]]
		appleturi = uri_parts[ 0..i ].join('/')
		debugMsg "  applet uri: %p" % [appleturi]

		applet = Registry[ appleturi ] or next
		debugMsg "  mapped to applet: %s" % [applet]
		
		appargs = uri_parts[ i+1..-1 ] + args
		
		# Map to either the default action or one specified by the uri
		if applet.actions.include?( appargs.first[PARTIAL_IDENTIFIER] )
			debugMsg "  mapped first arg %s to an action" % [args.first]
			chain << [ applet.class.name + '#' + args.slice!(0), args ]
		else
			debugMsg "  default action"
			chain << [ applet.class.name + '#default', args ]
		end
	end

	return chain
end


URIs.each do |uri|
	header "URI %s:\n" % [uri]
	urimap = map_uri( uri )
	debugMsg "  urimap: %p\n" % [urimap]
	urimap.each_index do |i|
		message "%s%s( %s )\n" % [
			'  ' * i,
			urimap[i].first,
			urimap[i].last.collect {|arg| "'#{arg}'" }.join(%q{, })
		  ]
	end
end



### I want the mapping to work something like this:
#
#  URI						 AppletChain
# ----------------------------+------------------------------------------------------
# /							| AccessControl#default()
# 							|
# /service					| AccessControl#delegate('service')
# 							|   ServiceController#default()
# 							|
# /service/api				| AccessControl#delegate('service', 'api')
# 							|   ServiceController#api('')
# 							|
# /service/api.wadl			| AccessControl#delegate('service', 'api.wadl')
# 							|   ServiceController#api('wadl')
# 							|
# /service/api.wadl/v2		| AccessControl#delegate('service', 'api.wadl', 'v2')
# 							|   ServiceController#api('wadl', 'v2')
# 							|
# /service/api/wadl			| AccessControl#delegate('service', 'api', 'wadl')
# 							|   ServiceController#api('wadl')
# 							|
# /service/api/wadl/v2		| AccessControl#delegate('service', 'api', 'wadl', 'v2')
# 							|   ServiceController#api('wadl', 'v2')
# 							|
# /service/users				| AccessControl#delegate('service', 'users')
# 							|   ServiceController#delegate('users')
# 							|     UserService#default()
# 							|
# /service/users.xml			| AccessControl#delegate('service', 'users.xml')
# 							|   ServiceController#delegate('users.xml')
# 							|     UserService#default('xml')
# 							|
# /service/users.js			| AccessControl#delegate('service', 'users.js')
# 							|   ServiceController#delegate('users.js')
# 							|     UserService#default('js')
# 							|
# 							|
# /service/groups/user/mgranger@laika.com
# 							| AccessControl#delegate('service', 'groups', 'user', 
# 							|     					'mgranger@laika.com')
# 							|   ServiceController#delegate('groups', 'user', 
# 							|     					'mgranger@laika.com')
# 							|     GroupService#user( 'mgranger@laika.com' )
# 							|
# /service/groups/user/mgranger@laika.com/js
# 							| AccessControl#delegate('service', 'groups', 'user', 
# 							|     					'mgranger@laika.com')
# 							|   ServiceController#delegate('groups', 'user', 
# 							|     					'mgranger@laika.com')
# 							|     GroupService#user( 'mgranger@laika.com' )
# 							|
# /service/groups/user/mgranger@laika.com/xml
# 							| AccessControl#delegate('service', 'groups', 'user', 
# 							|     					'mgranger@laika.com')
# 							|   ServiceController#delegate('groups', 'user', 
# 							|     					'mgranger@laika.com')
# 							|     GroupService#user( 'mgranger@laika.com' )
							
							
