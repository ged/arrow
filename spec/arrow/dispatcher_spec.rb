#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'tempfile'
	require 'tmpdir'
	require 'pathname'
	require 'apache/fakerequest'
	require 'arrow'
	require 'arrow/dispatcher'
	require 'arrow/config-loaders/yaml'
	require 'spec/lib/matchers'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


TEST_CONFIG_HASH = {
	:logging => { :global=>"notice" },
	:applets => {
		:pollInterval	=> 5,
		:pattern		=> "*.rb",
		:missingApplet	=> "/missing",
		:errorApplet	=> "/error",
		:path => [
			"test/applets",
		  ],
		:config => {},
		:layout => {
			"/"			=> "Setup",
			"/missing"	=> "NoSuchAppletHandler",
			"/error"	=> "ErrorHandler",
		  },
	  },

	:session => {
		:idType			=> "md5:.",
		:lockType		=> "recommended",
		:storeType		=> "file:tests/sessions",
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
			"tests/data",
		  ],
		:loader		=> "Arrow::Template",
	  },
}



#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::Dispatcher do
	include TimeMatchers
	
	TEST_CONFIG = Arrow::Config.new( TEST_CONFIG_HASH )

	before(:all) do
		@tmpfile = Tempfile.new( 'test.conf', '.' )
		TEST_CONFIG.write( @tmpfile.path )
		@tmpfile.close
	end
	
	after( :all ) do
		@tmpfile.delete
	end


	after(:each) do
		Pathname.glob( "%s/arrow-fatal*" % Dir.tmpdir ).each do |f|
			f.unlink
		end
	end


	### Specs
	
	it "raises an error when its factory method is called with " +
		    "something other than a String or Hash" do
	    lambda {
			Arrow::Dispatcher.create( :something )
		}.should raise_error( ArgumentError, /invalid config hash/i )
	end
	
	it "writes a crashlog to TMPDIR when create fails" do
		crashlog = Pathname.new( Dir.tmpdir + "/arrow-fatal.log.#{$$}" )
		crashlog.unlink if crashlog.exist?
		
		begin
			Arrow::Dispatcher.create( :something )
		rescue ArgumentError
		end
		
		crashlog.exist?.should == true
		crashlog.ctime.should be_after( Time.now - 60 )
	end
	
	it "assumes a string configspec is a default configfile" do
		dispatcher = Arrow::Dispatcher.create( @tmpfile.path )
		Arrow::Dispatcher.instance.should equal( dispatcher )
	end
	
	it "reads dispatcher configs from an object's #read method if it has one" do
		config_obj = mock( "configuration object", :null_object => true )
		config_obj.should_receive( :respond_to? ).with( :read ).and_return( true )
		config_obj.should_receive( :read ).and_return( YAML.dump({}) )
		
		Arrow::Dispatcher.create_from_hosts_file( config_obj )
	end
end


describe Arrow::Dispatcher, " (an instance)" do
	it "has an associated name" do
		@config = Arrow::Config.new( TEST_CONFIG_HASH )
		@dispatcher = Arrow::Dispatcher.new( "test", @config )
	    @dispatcher.name.should == "test"
	end
end

describe Arrow::Dispatcher, " running under $SAFE = 1" do
	before(:all) do
		@configfile = Tempfile.new( 'test.conf', '.' )
		@configfile.print( YAML.dump(TEST_CONFIG_HASH) )
		@configfile.close

		hosts_config = YAML.dump({
			:testing => @configfile.path,
		})
		@host_configio = StringIO.new( hosts_config )
		@host_configio.taint
	end

	after(:all) do
		@configfile.delete
	end

	# Fake actually loading the config file
	before(:each) do
		@host_configio.rewind
	end
	
	it "should be able to create dispatchers from a tainted hosts file" do
		$SAFE = 1
		rval = nil

		lambda {
			rval = Arrow::Dispatcher.create_from_hosts_file( @host_configio )
		}.should_not raise_error()
		
		rval.should be_an_instance_of( Hash )
		rval.should have(2).keys
		rval.keys.should include( :testing )
		rval.keys.should include( File.expand_path(@configfile.path) )
	end
end


# vim: set nosta noet ts=4 sw=4:
