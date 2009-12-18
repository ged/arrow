#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'spec'
require 'apache/fakerequest'
require 'arrow'
require 'arrow/logger'

require 'spec/lib/matchers'
require 'spec/lib/constants'
require 'spec/lib/helpers'


include Arrow::TestConstants


#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::Logger do
	include Arrow::SpecHelpers

	before( :each ) do
		Arrow::Logger.reset
	end
	
	after( :all ) do
		Arrow::Logger.reset
	end
	

	it "has a global anonymous singleton instance" do
		Arrow::Logger.global.should be_an_instance_of( Arrow::Logger )
		Arrow::Logger.global.module.should == Object
	end


	it "writes every message to the global logger" do
		outputter = mock( "logging outputter" )
		
		Arrow::Logger.global.outputters << outputter
		
		outputter.should_receive( :write ).with( duck_type(:strftime), :debug, "(global)", nil, "test message" )
		
		Arrow::Logger.global.level = :debug
		Arrow::Logger.global.debug "test message"
	end


	it "doesn't output a message if its level is less than the level set in the logger" do
		outputter = mock( "logging outputter" )
		
		Arrow::Logger.global.outputters << outputter
		
		outputter.should_not_receive( :write ).
			with( duck_type(:strftime), :debug, "(global)", nil, "debug message" )
		outputter.should_receive( :write ).
			with( duck_type(:strftime), :info, "(global)", nil, "info message" )
		
		Arrow::Logger.global.level = :info
		Arrow::Logger.global.debug "debug message"
		Arrow::Logger.global.info "info message"
	end


	it "creates loggers for specific classes via its index operator" do
		klass = Class.new
		Arrow::Logger[ klass ].should be_an_instance_of( Arrow::Logger )
		Arrow::Logger[ klass ].should_not == Arrow::Logger.global
	end
	

	it "propagates log messages from class-specific loggers to the global logger" do
		outputter = mock( "logging outputter" )
		classoutputter = mock( "outputter for a class" )

		klass = Class.new

		Arrow::Logger.global.outputters << outputter
		Arrow::Logger.global.level = :info

		Arrow::Logger[ klass ].outputters << classoutputter
		Arrow::Logger[ klass ].level = :info
		
		outputter.should_receive( :write ).
			with( duck_type(:strftime), :info, klass.inspect, nil, "test message" )
		classoutputter.should_receive( :write ).
			with( duck_type(:strftime), :info, klass.inspect, nil, "test message" )
		
		Arrow::Logger[ klass ].info "test message"
	end
	

	it "propagates log messages from specific class loggers to more-general ones" do
		outputter = mock( "logging outputter" )
		classoutputter = mock( "outputter for a class" )
		subclassoutputter = mock( "outputter for a subclass" )

		klass = Class.new
		subclass = Class.new( klass )

		Arrow::Logger.global.outputters << outputter
		Arrow::Logger.global.level = :info

		Arrow::Logger[ klass ].outputters << classoutputter
		Arrow::Logger[ klass ].level = :info
		
		Arrow::Logger[ subclass ].outputters << subclassoutputter
		Arrow::Logger[ subclass ].level = :info
		
		outputter.should_receive( :write ).
			with( duck_type(:strftime), :info, subclass.inspect, nil, "test message" )
		classoutputter.should_receive( :write ).
			with( duck_type(:strftime), :info, subclass.inspect, nil, "test message" )
		subclassoutputter.should_receive( :write ).
			with( duck_type(:strftime), :info, subclass.inspect, nil, "test message" )
		
		Arrow::Logger[ subclass ].info "test message"
	end
	
	it "never writes a message more than once to an outputter, even it it's set on more than " +
	   "one logger in the hierarchy" do
		outputter = mock( "logging outputter" )

		klass = Class.new
		subclass = Class.new( klass )

		Arrow::Logger.global.outputters << outputter
		Arrow::Logger.global.level = :info

		Arrow::Logger[ klass ].outputters << outputter
		Arrow::Logger[ klass ].level = :info

		Arrow::Logger[ subclass ].outputters << outputter
		Arrow::Logger[ subclass ].level = :info

		outputter.should_receive( :write ).once.
			with( duck_type(:strftime), :info, subclass.inspect, nil, "test message" )

		Arrow::Logger[ subclass ].info "test message"
	end


	it "can look up a logger by class name" do
		Arrow::Logger[ "Arrow::Object" ].should be_equal( Arrow::Logger[Arrow::Object] )
	end
	

	it "can look up a logger by an instance of a class" do
		Arrow::Logger[ Arrow::Object.new ].should be_equal( Arrow::Logger[Arrow::Object] )
	end
	

	it "can return a readable name for the module which it logs for" do
		Arrow::Logger[ Arrow::Object ].readable_name.should == 'Arrow::Object'
	end
	
	it "can return a readable name for the module which it logs for, even if it's an anonymous class" do
		klass = Class.new
		Arrow::Logger[ klass ].readable_name.should == klass.inspect
	end
	
	it "can return a readable name for the global logger" do
		Arrow::Logger.global.readable_name.should == '(global)'
	end


	it "can return its current level as a Symbol" do
		Arrow::Logger.global.level = :notice
		Arrow::Logger.global.readable_level.should == :notice
	end


	it "knows which loggers are for more-general classes" do
		mod = Module.new
		class1 = Class.new
		class2 = Class.new( class1 ) do
			include mod
		end
		class3 = Class.new( class2 )
		
		Arrow::Logger[ class3 ].hierloggers.should == [
			Arrow::Logger[class3],
			Arrow::Logger[class2],
			Arrow::Logger[mod],
			Arrow::Logger[class1],
			Arrow::Logger.global,
		]
	end

	it "knows which loggers are for more-general classes that are of the specified level or lower" do
		mod = Module.new
		class1 = Class.new
		class2 = Class.new( class1 ) do
			include mod
		end
		class3 = Class.new( class2 )
		
		Arrow::Logger[ class2 ].level = :debug
		
		Arrow::Logger[ class3 ].hierloggers( :debug ).should == [
			Arrow::Logger[class2],
		]
	end

	it "can yield loggers for more-general classes" do
		mod = Module.new
		class1 = Class.new
		class2 = Class.new( class1 ) do
			include mod
		end
		class3 = Class.new( class2 )
		
		loggers = []
		
		Arrow::Logger[ class3 ].hierloggers do |l|
			loggers << l
		end
		
		loggers.should == [
			Arrow::Logger[class3],
			Arrow::Logger[class2],
			Arrow::Logger[mod],
			Arrow::Logger[class1],
			Arrow::Logger.global,
		]
	end

	it "knows which outputters are for more-general classes" do
		mod = Module.new
		class1 = Class.new
		class2 = Class.new( class1 ) do
			include mod
		end
		class3 = Class.new( class2 )
		
		outputter1 = stub( "class2's outputter" )
		Arrow::Logger[class2].outputters << outputter1
		outputter2 = stub( "mod's outputter" )
		Arrow::Logger[mod].outputters << outputter2
		
		Arrow::Logger[ class3 ].hieroutputters.should == [
			outputter1,
			outputter2,
		]
	end
	
	it "can yield outputters for more-general classes" do
		mod = Module.new
		class1 = Class.new
		class2 = Class.new( class1 ) do
			include mod
		end
		class3 = Class.new( class2 )
		
		outputter1 = stub( "class2's outputter" )
		Arrow::Logger[class2].outputters << outputter1
		outputter2 = stub( "mod's outputter" )
		Arrow::Logger[mod].outputters << outputter2

		outputters = []
		Arrow::Logger[ class3 ].hieroutputters do |outp, logger|
			outputters << outp
		end
		
		outputters.should == [
			outputter1,
			outputter2,
		]
	end


	it "includes an exception's backtrace if it is set at the log message" do
		outputter = mock( "outputter" )
		Arrow::Logger.global.outputters << outputter
		
		outputter.should_receive( :write ).
			with( duck_type(:strftime), :error, "(global)", nil, %r{Glah\.:\n    } )
		
		begin
			raise "Glah."
		rescue => err
			Arrow::Logger.global.error( err )
		end
	end


	it "can parse a single-word log setting" do
		Arrow::Logger.parse_log_setting( 'debug' ).should == [ :debug, nil ]
	end
	
	it "can parse a two-word log setting" do
		level, uri = Arrow::Logger.parse_log_setting( 'info apache' )

		level.should == :info
		uri.should be_an_instance_of( URI::Generic )
		uri.path.should == 'apache'
	end

	it "can parse a word+uri log setting" do
		uristring = 'error dbi://www:password@localhost/www.errorlog?driver=postgresql'
		level, uri = Arrow::Logger.parse_log_setting( uristring )

		level.should == :error
		uri.should be_an_instance_of( URI::Generic )
		uri.scheme.should == 'dbi'
		uri.user.should == 'www'
		uri.password.should == 'password'
		uri.host.should == 'localhost'
		uri.path.should == '/www.errorlog'
		uri.query.should == 'driver=postgresql'
	end


	it "resets the level of any message written to it if its forced_level attribute is set" do
		klass = Class.new
		outputter = mock( "outputter" )
		globaloutputter = mock( "global outputter" )

		Arrow::Logger[ klass ].level = :info
		Arrow::Logger[ klass ].forced_level = :debug
		Arrow::Logger[ klass ].outputters << outputter

		Arrow::Logger.global.level = :debug
		Arrow::Logger.global.outputters << globaloutputter
		
		outputter.should_not_receive( :write )
		globaloutputter.should_receive( :write ).
			with( duck_type(:strftime), :debug, klass.inspect, nil, 'Some annoying message' )
		
		Arrow::Logger[ klass ].info( "Some annoying message" )
	end
	
end

# vim: set nosta noet ts=4 sw=4:
