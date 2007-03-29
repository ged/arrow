#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'arrow'
	require 'arrow/spechelpers'
	require 'arrow/transaction'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


#####################################################################
###	C O N T E X T S
#####################################################################

context "An instance of an transaction" do
	setup do
		@fakerequest = Apache::Request.new( '/test' )
		@txn = Arrow::Transaction.new( @fakerequest, nil, nil )
	end

	
	specify "knows that a form was submitted if there's a urlencoded form content-type header" do
		@fakerequest.headers_in['content-type'] = 'application/x-www-form-urlencoded'
		@fakerequest.request_method = 'POST'

		@txn.should be_a_form_request
	end

	
end


# vim: set nosta noet ts=4 sw=4:
