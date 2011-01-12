#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'spec'
require 'arrow'
require 'arrow/#{vars[:specified_class].downcase}'


#####################################################################
###	C O N T E X T S
#####################################################################

describe #{vars[:specified_class]} do

	
	
end

# vim: set nosta noet ts=4 sw=4:
