#!/usr/bin/env ruby

# Test to see if Struct can be inherited from usefully.

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
}

try( "to subclass Struct as ConfigStruct" ) {
	class ConfigStruct < Struct
		def to_h
			rhash = {}
			self.members.collect {|name| name.to_sym}.each {|sym|
				val = self.send(sym)
				case val
				when ConfigStruct
					rhash[ sym ] = val.to_h
				else
					rhash[ sym ] = val
				end
			}
			return rhash
		end
	end
}

try( "to make ConfigStruct derivatives" ) {
	ArrowConfig = ConfigStruct.new( "ArrowConfig", :templates, :apps )
	TemplateConfig = ConfigStruct.new( "ArrowTemplateConfig", :path, :cache )
	AppsConfig = ConfigStruct.new( "ArrowAppsConfig", :path )
}

tconf, aconf, conf = nil, nil, nil
try( "to make some ConfigStruct derivative objects" ) {
	tconf = TemplateConfig.new( "/www:/www/templates", true )
	aconf = AppsConfig.new( "/www/apps" )
	conf = ArrowConfig.new( tconf, aconf )

	[tconf, aconf, conf]
}

try( "conf.templates.path", binding )
try( "conf.templates.cache", binding )
try( "conf.apps.path", binding )

try( "to dump the toplevel configstruct to a hash" ) {
	conf.to_h
}

