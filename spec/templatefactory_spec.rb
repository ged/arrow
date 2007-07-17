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
	require 'arrow/templatefactory'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


### A testing loader class
class Arrow::TestingClassTemplateLoader
	def self::load( *args )
		# Mocked
	end
end

### A testing loader object
class Arrow::TestingInstanceTemplateLoader
	def initialize( config )
	end

	def load( *args )
		# Mocked
	end
end


#####################################################################
###	C O N T E X T S
#####################################################################

describe "A TemplateFactory instance configured with a loader class" do

	before(:each) do
		tmplconfig = mock( "templates config", :null_object => true )
		tmplconfig.stub!( :cache ).and_return( false )
	    tmplconfig.stub!( :loader ).
			and_return( 'Arrow::TestingClassTemplateLoader' )

		config = stub( "config", :templates => tmplconfig )

		@factory = Arrow::TemplateFactory.new( config )
	end


	it "has the loader class object registered as its loader" do
	    @factory.loader.should == Arrow::TestingClassTemplateLoader
	end
	
	it "calls the loader's #load method to load templates" do
		loader = mock( "loader", :null_object => true )
		@factory.loader = loader
		@factory.path = :path
		
		loader.should_receive( :load ).with( 'templatename', :path ).
			and_return( :template_object )
		
	    @factory.load_from_file( 'templatename' ).should == :template_object
	end
end

describe "A TemplateFactory instance configured with a loader object" do
	before(:each) do
		tmplconfig = mock( "templates config", :null_object => true )
		tmplconfig.stub!( :cache ).and_return( false )
	    tmplconfig.stub!( :loader ).
			and_return( 'Arrow::TestingInstanceTemplateLoader' )

		config = stub( "config", :templates => tmplconfig )

		@factory = Arrow::TemplateFactory.new( config )
	end


	it "has the loader class object registered as its loader" do
	    @factory.loader.should be_an_instance_of( Arrow::TestingInstanceTemplateLoader )
	end
	
	it "calls the loader's #load method to load templates" do
		loader = mock( "loader", :null_object => true )
		@factory.loader = loader
		@factory.path = :path
		
		loader.should_receive( :load ).with( 'templatename', :path ).
			and_return( :template_object )
		
	    @factory.load_from_file( 'templatename' ).should == :template_object
	end
end


describe "A TemplateFactory instance configured to use caching" do
	before(:each) do
		tmplconfig = mock( "templates config", :null_object => true )
	    tmplconfig.stub!( :loader ).
			and_return( 'Arrow::TestingInstanceTemplateLoader' )
		tmplconfig.stub!( :cache ).and_return( true )
		tmplconfig.stub!( :cacheConfig ).and_return( {} )

		config = stub( "config", :templates => tmplconfig )

		@factory = Arrow::TemplateFactory.new( config )
		@mock_cache = mock( "cache", :null_object => true )
	    @factory.cache = @mock_cache
	end


	it "fetches templates through the cache" do
		template = stub( "template", :changed? => false, :dup => :template_copy )
		@mock_cache.should_receive( :fetch ).with( :templatename ).
			and_return( template )
		
		@factory.get_template( :templatename ).should == :template_copy
	end

	it "invalidates cached templates that have changed since loading" do
		template = stub( "template", :changed? => true, :dup => :template_copy )
		@mock_cache.should_receive( :fetch ).twice.with( :templatename ).
			and_return( template )
		@mock_cache.should_receive( :invalidate ).with( :templatename )
		
		@factory.get_template( :templatename ).should == :template_copy
	    
	end
	
end

describe "A TemplateFactory instance configured to not use caching" do
	before(:each) do
		tmplconfig = mock( "templates config", :null_object => true )
	    tmplconfig.stub!( :loader ).
			and_return( 'Arrow::TestingInstanceTemplateLoader' )
		tmplconfig.stub!( :cache ).and_return( false )
		tmplconfig.stub!( :path ).and_return( :path )

		config = stub( "config", :templates => tmplconfig )

		@factory = Arrow::TemplateFactory.new( config )
		@mock_loader = mock( "template loader" )
		@factory.loader = @mock_loader
	end

	it "should not fetch templates through the cache" do
	    @mock_loader.should_receive( :load ).
			with( :template_name, :path ).
			and_return( :template )
		@factory.get_template( :template_name ).should == :template
	end
end


# vim: set nosta noet ts=4 sw=4:
