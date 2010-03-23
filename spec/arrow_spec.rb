#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}


require 'spec'
require 'spec/lib/constants'
require 'spec/lib/helpers'

require 'arrow'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow do
	include Arrow::SpecHelpers

	it "returns a version string if asked" do
		Arrow.version_string.should =~ /\w+ [\d.]+/
	end


	it "returns a version string with a build number if asked" do
		Arrow.version_string(true).should =~ /\w+ [\d.]+ \(build [[:xdigit:]]+\)/
	end

end

