#!/usr/bin/ruby

# 
# Constants for testing
# 
# 

require 'arrow'
require 'arrow/config'
require 'arrow/constants'


### A module of testing constants
module Arrow::TestConstants

	include Arrow::Constants

	# Testing config values
	TEST_CONFIG_HASH = {
		:logging => { :global=>"notice" },
		:gems               => {
			:require_signed => false,
			:autoinstall    => false,
			:path           => Arrow::Path.new([ "gems", *Gem.path ]),
			:applets        => {},
		},
		:applets => {
			:pollInterval	=> 5,
			:pattern		=> "*.rb",
			:missingApplet	=> "/missing",
			:errorApplet	=> "/error",
			:path => [
				"spec/data/applets",
				"applets"
			  ],
			:config => {},
			:layout => {
				:"/"			=> "Setup",
				:"/missing"	=> "NoSuchAppletHandler",
				:"/error"	=> "ErrorHandler",
			  },
		  },

		:session => {
			:idType			=> "md5:.",
			:lockType		=> "recommended",
			:storeType		=> "file:spec/data/sessions",
			:idName			=> "arrow-session",
			:rewriteUrls	=> true,
			:expires		=> "+48h",
		  },

		:templates => {
			:cacheConfig	=> {
				:maxNum			=> 20,
				:maxSize		=> 2621440,
				:maxObjSize		=> 131072,
				:expiration		=> 36
			  },
			:cache		=> true,
			:path		=> [
				"spec/data",
			  ],
			:loader		=> "Arrow::Template",
		  },
	}

	TEST_CONFIG_HASH.freeze
	
	
	TEST_CONFIG = Arrow::Config.new( TEST_CONFIG_HASH )
	TEST_CONFIG.freeze
	
	
end


