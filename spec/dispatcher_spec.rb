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
	require 'arrow/dispatcher'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


TEST_CONFIG = {
 :applets=>
  {:pollInterval=>5,
   :path=>["test/applets"],
   :config=>{},
   :layout=>
    {:/=>"Setup",
     :"/missing"=>"NoSuchAppletHandler",
     :"/error"=>"ErrorHandler"},
   :pattern=>"*.rb",
   :missingApplet=>"/missing",
   :errorApplet=>"/error"},
 :session=>
  {:idType=>"md5:.",
   :lockType=>"recommended",
   :storeType=>"file:tests/sessions",
   :idName=>"arrow-session",
   :rewriteUrls=>true,
   :expires=>"+48h"},
 :logLevel=>"debug",
 :logging=>{:global=>"notice"},
 :templates=>
  {:cacheConfig=>
    {:maxNum=>20, :maxSize=>2621440, :maxObjSize=>131072, :expiration=>36},
   :cache=>true,
   :path=>["tests/data"],
   :loader=>"Arrow::Template"},
 :templateLogLevel=>"notice",
 :startMonitor=>false
}


#####################################################################
###	C O N T E X T S
#####################################################################

context "A dispatcher" do
	setup do
		@config = Arrow::Config.new( TEST_CONFIG )
		@dispatcher = Arrow::Dispatcher.new( "test", @config )
	end

send

context "A dispatcher created from a single config file" do
	
end

context "A dispatcher created from a hash of configfiles" do
	
end


# vim: set nosta noet ts=4 sw=4:
