#!/usr/bin/env ruby

require 'yaml'
require 'tmpdir'

require 'pathname'


# 
# The Arrow module, a namespace container for classes in the
# Arrow web application framework.
# 
# == Authors
# 
# * Martin Chase <mchase@rubycrafters.com>
# * Michael Granger <mgranger@rubycrafters.com>
# * David McCorkhill <dmccorkhill@rubycrafters.com>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
module Arrow

	# Library version
	VERSION = '1.1.0'

	# VCS revision
	REVISION = %q$Revision$


	require 'arrow/constants'
	require 'arrow/monkeypatches'
	require 'arrow/exceptions'
	require 'arrow/mixins'
	require 'arrow/logger'


	# Hook up PluginFactory logging to Arrow logging
	PluginFactory.logger_callback = lambda do |lvl, msg|
		Arrow::Logger[PluginFactory].debug( msg )
	end
	PluginFactory.log.debug( "Hooked up PluginFactory logging through Arrow's logger." )


	### Return the library's version string
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, VERSION ]
		vstring << " (build %s)" % [ REVISION[/: ([[:xdigit:]]+)/, 1] || '0' ] if include_buildnum
		return vstring
	end

end # module Arrow
