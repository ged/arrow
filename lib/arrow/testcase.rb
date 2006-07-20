#!/usr/bin/ruby
# 
# This is an abstract test case class for building Test::Unit unit tests for the
# Arrow web application framework. It consolidates most of the maintenance work
# that must be done to build a test file by adjusting the $LOAD_PATH to include
# the lib/ and ext/ directories, as well as adding some other useful methods
# that make building and maintaining the tests much easier (IMHO). See the docs
# for Test::Unit for more info on the particulars of unit testing.
# 
# == Synopsis
# 
#	$LOAD_PATH.unshift "tests/lib" unless $LOAD_PATH.include?("tests/lib")
#	require 'arrow/testcase'
#
#	class MySomethingTest < Arrow::TestCase
#		def set_up
#			super()
#			@foo = 'bar'
#		end
#
#		def test_00_something
#			obj = nil
#			assert_nothing_raised { obj = MySomething.new }
#			assert_instance_of MySomething, obj
#			assert_respond_to :myMethod, obj
#		end
#	end
# 
# == Rcsid
# 
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Copyright (c) 2003, 2004, 2006 RubyCrafters, LLC.
# 
# This work is licensed under the Creative Commons Attribution License. To view
# a copy of this license, visit http://creativecommons.org/licenses/by/1.0 or
# send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California
# 94305, USA.
#
# 

basedir = File.dirname(File.dirname( __FILE__ ))
$LOAD_PATH.unshift "#{basedir}/ext", "#{basedir}/lib" unless
	$LOAD_PATH.include?( "#{basedir}/lib" )

begin 
	require "readline"
	include Readline
rescue LoadError
	def readline( prompt )
		$defout.print( prompt )
		$defout.flush
		return $stdin.gets
	end
end

require 'test/unit'
require 'test/unit/assertions'
require 'test/unit/util/backtracefilter'

require 'flexmock'
require 'apache/fakerequest'

require 'arrow'


### Test case class
class Arrow::TestCase < Test::Unit::TestCase

	@@methodCounter = 0

	# Set some ANSI escape code constants (Shamelessly stolen from Perl's
	# Term::ANSIColor by Russ Allbery <rra@stanford.edu> and Zenin
	# <zenin@best.com>
	AnsiAttributes = {
		'clear'      => 0,
		'reset'      => 0,
		'bold'       => 1,
		'dark'       => 2,
		'underline'  => 4,
		'underscore' => 4,
		'blink'      => 5,
		'reverse'    => 7,
		'concealed'  => 8,

		'black'      => 30,   'on_black'   => 40, 
		'red'        => 31,   'on_red'     => 41, 
		'green'      => 32,   'on_green'   => 42, 
		'yellow'     => 33,   'on_yellow'  => 43, 
		'blue'       => 34,   'on_blue'    => 44, 
		'magenta'    => 35,   'on_magenta' => 45, 
		'cyan'       => 36,   'on_cyan'    => 46, 
		'white'      => 37,   'on_white'   => 47
	}

	# The name of the file containing marshalled configuration values
	ConfigSaveFile = "test.cfg"

	### Inheritance callback -- adds @setupMethods and @teardownMethods ivars
	### and accessors to the inheriting class.
	def self.inherited( klass )
		klass.module_eval {
			@setupMethods = []
			@teardownMethods = []

			class << self
				attr_accessor :setupMethods
				attr_accessor :teardownMethods
			end
		}
	end


	### Returns a String containing the specified ANSI escapes suitable for
	### inclusion in another string. The <tt>attributes</tt> should be one
	### or more of the keys of AnsiAttributes.
	def self.ansiCode( *attributes )
		return '' unless /(?:xterm(?:-color)?|eterm|linux)/i =~ ENV['TERM']

		attr = attributes.collect {|a|
			AnsiAttributes[a] ? AnsiAttributes[a] : nil
		}.compact.join(';')
		if attr.empty? 
			return ''
		else
			return "\e[%sm" % attr
		end
	end


	### Output the specified <tt>msgs</tt> joined together to
	### <tt>STDERR</tt> if <tt>$DEBUG</tt> is set.
	def self.debugMsg( *msgs )
		return unless $DEBUG
		self.message "%sDEBUG>>> %s %s" %
			[ ansiCode('dark', 'white'), msgs.join(''), ansiCode('reset') ]
	end


	### Output the specified <tt>msgs</tt> joined together to
	### <tt>STDOUT</tt>.
	def self.message( *msgs )
		$stderr.puts msgs.join('')
		$stderr.flush
	end

	### Append a setup block for the current testcase
	def self.addSetupBlock( &block )
		@@methodCounter += 1
		newMethodName = "setup_#{@@methodCounter}".intern
		define_method( newMethodName, &block )
		self.setupMethods.push newMethodName
	end


	### Prepend a teardown block for the current testcase
	def self.addTeardownBlock( &block )
		@@methodCounter += 1
		newMethodName = "teardown_#{@@methodCounter}".intern
		define_method( newMethodName, &block )
		self.teardownMethods.unshift newMethodName
	end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################


	######
	public
	######

	### Run dynamically-added setup methods
	def setup( *args )
		if self.class < Arrow::TestCase
			self.class.setupMethods.each {|sblock|
				self.send( sblock )
			}
		end
	end
	alias_method :set_up, :setup


	### Run dynamically-added teardown methods
	def teardown( *args )
		if self.class < Arrow::TestCase
			self.class.teardownMethods.each {|tblock|
				self.send( tblock )
			}
		end
	end
	alias_method :tear_down, :teardown


	### Skip the current step (called from #setup) with the +reason+ given.
	def skip( reason=nil )
		if reason
			msg = "Skipping %s: %s" % [ @method_name, reason ]
		else
			msg = "Skipping %s: No reason given." % @method_name
		end

		$stderr.puts( msg ) if $VERBOSE
		@method_name = :skipped_test
	end


	def skipped_test # :nodoc:
	end


	### Add the specified +block+ to the code that gets executed by #setup.
	def addSetupBlock( &block ); self.class.addSetupBlock( &block ); end


	### Add the specified +block+ to the code that gets executed by #teardown.
	def addTeardownBlock( &block ); self.class.addTeardownBlock( &block ); end


	### Turn off the stupid 'No tests were specified'
	def default_test; end

	#################################################################
	###	A S S E R T I O N S
	#################################################################

	### Test Hashes for equivalent content
	def assert_hash_equal( expected, actual, msg="" )
		errmsg = "Expected hash <%p> to be equal to <%p>" % [expected, actual]
		errmsg += ": #{msg}" unless msg.empty?

		assert_block( errmsg ) {
			diffs = compare_hashes( expected, actual )
			unless diffs.empty?
				errmsg += ": " + diffs.join("; ")
				return false
			else
				return true
			end
		}
	rescue Test::Unit::AssertionFailedError => err
		cutframe = err.backtrace.reverse.find {|frame|
			/assert_hash_equal/ =~ frame
		}
		firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
		Kernel.raise( err, err.message, err.backtrace[firstIdx..-1] )
	end


	### Compare two hashes for content, returning a list of their differences as
	### descriptions. An empty Array return-value means they were the same.
	def compare_hashes( hash1, hash2, subkeys=nil )
		diffs = []
		seenKeys = []

		hash1.each {|k,v|
			if !hash2.key?( k )
				diffs << "missing %p pair" % k
			elsif hash1[k].is_a?( Hash ) && hash2[k].is_a?( Hash )
				diffs.push( compare_hashes(hash1[k], hash2[k]) )
			elsif hash2[k] != hash1[k]
				diffs << "value for %p expected to be %p, but was %p" %
					[ k, hash1[k], hash2[k] ]
			else
				seenKeys << k
			end
		}

		extraKeys = (hash2.keys - hash1.keys)
		diffs << "extra key/s: #{extraKeys.join(', ')}" unless extraKeys.empty?

		return diffs.flatten
	end


	### Test Hashes (or any other objects with a #keys method) for key set
	### equality
	def assert_same_keys( expected, actual, msg="" )
		errmsg = "Expected keys of <%p> to be equal to those of <%p>" %
			[ actual, expected ]
		errmsg += ": #{msg}" unless msg.empty?

		ekeys = expected.keys; akeys = actual.keys
		assert_block( errmsg ) {
			diffs = []

			# XOR the arrays and make a diff for each one
			((ekeys + akeys) - (ekeys & akeys)).each do |key|
				if ekeys.include?( key )
					diffs << "missing key %p" % [key]
				else
					diffs << "extra key %p" % [key]
				end
			end

			unless diffs.empty?
				errmsg += "\n" + diffs.join("; ")
				return false
			else
				return true
			end
		}
	rescue Test::Unit::AssertionFailedError => err
		cutframe = err.backtrace.reverse.find {|frame|
			/assert_hash_equal/ =~ frame
		}
		firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
		Kernel.raise( err, err.message, err.backtrace[firstIdx..-1] )
	end

	
	### Override the stupid deprecated #assert_not_nil so when it
	### disappears, code doesn't break.
	def assert_not_nil( obj, msg=nil )
		msg ||= "<%p> expected to not be nil." % obj
		assert_block( msg ) { !obj.nil? }
	rescue Test::Unit::AssertionFailedError => err
		cutframe = err.backtrace.reverse.find {|frame|
			/assert_not_nil/ =~ frame
		}
		firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
		Kernel.raise( err, err.message, err.backtrace[firstIdx..-1] )
	end


	### Succeeds if +obj+ include? +item+.
	def assert_include( item, obj, msg=nil )
		msg ||= "<%p> expected to include <%p>." % [ obj, item ]
		assert_block( msg ) { obj.respond_to?(:include?) && obj.include?(item) }
	rescue Test::Unit::AssertionFailedError => err
		cutframe = err.backtrace.reverse.find {|frame|
			/assert_include/ =~ frame
		}
		firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
		Kernel.raise( err, err.message, err.backtrace[firstIdx..-1] )
	end


	### Negative of assert_respond_to
	def assert_not_tainted( obj, msg=nil )
		msg ||= "<%p> expected to NOT be tainted" % [ obj ]
		assert_block( msg ) {
			!obj.tainted?
		}
	rescue Test::Unit::AssertionFailedError => err
		cutframe = err.backtrace.reverse.find {|frame|
			/assert_not_tainted/ =~ frame
		}
		firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
		Kernel.raise( err, err.message, err.backtrace[firstIdx..-1] )
	end


	### Negative of assert_respond_to
	def assert_not_respond_to( obj, meth )
		msg = "%s expected NOT to respond to '%s'" %
			[ obj.inspect, meth ]
		assert_block( msg ) {
			!obj.respond_to?( meth )
		}
	rescue Test::Unit::AssertionFailedError => err
		cutframe = err.backtrace.reverse.find {|frame|
			/assert_not_respond_to/ =~ frame
		}
		firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
		Kernel.raise( err, err.message, err.backtrace[firstIdx..-1] )
	end


	### Assert that the instance variable specified by +sym+ of an +object+
	### is equal to the specified +value+. The '@' at the beginning of the
	### +sym+ will be prepended if not present.
	def assert_ivar_equal( value, object, sym )
		sym = "@#{sym}".intern unless /^@/ =~ sym.to_s
		msg = "Instance variable '%s'\n\tof <%s>\n\texpected to be <%s>\n" %
			[ sym, object.inspect, value.inspect ]
		msg += "\tbut was: <%p>" % [ object.instance_variable_get(sym) ]
		assert_block( msg ) {
			value == object.instance_variable_get(sym)
		}
	rescue Test::Unit::AssertionFailedError => err
		cutframe = err.backtrace.reverse.find {|frame|
			/assert_ivar_equal/ =~ frame
		}
		firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
		Kernel.raise( err, err.message, err.backtrace[firstIdx..-1] )
	end


	### Assert that the specified +object+ has an instance variable which
	### matches the specified +sym+. The '@' at the beginning of the +sym+
	### will be prepended if not present.
	def assert_has_ivar( sym, object )
		sym = "@#{sym}" unless /^@/ =~ sym.to_s
		msg = "Object <%s> expected to have an instance variable <%s>" %
			[ object.inspect, sym ]
		assert_block( msg ) {
			object.instance_variables.include?( sym.to_s )
		}
	rescue Test::Unit::AssertionFailedError => err
		cutframe = err.backtrace.reverse.find {|frame|
			/assert_has_ivar/ =~ frame
		}
		firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
		Kernel.raise( err, err.message, err.backtrace[firstIdx..-1] )
	end


	### Assert that the specified +str+ does *not* match the given regular
	### expression +re+.
	def assert_not_match( re, str )
		msg = "<%s> expected not to match %p" %
			[ str, re ]
		assert_block( msg ) {
			!re.match( str )
		}
	rescue Test::Unit::AssertionFailedError => err
		cutframe = err.backtrace.reverse.find {|frame|
			/assert_not_match/ =~ frame
		}
		firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
		Kernel.raise( err, err.message, err.backtrace[firstIdx..-1] )
	end


	### Assert that the specified +klass+ defines the specified instance
	### method +meth+.
	def assert_has_instance_method( klass, meth )
		msg = "<%s> expected to define instance method #%s" %
			[ klass, meth ]
		assert_block( msg ) {
			klass.instance_methods.include?( meth.to_s )
		}
	rescue Test::Unit::AssertionFailedError => err
		cutframe = err.backtrace.reverse.find {|frame|
			/assert_has_instance_method/ =~ frame
		}
		firstIdx = (err.backtrace.rindex( cutframe )||0) + 1
		Kernel.raise( err, err.message, err.backtrace[firstIdx..-1] )
	end



	#################################################################
	###	M E S S A G E   M E T H O D S
	#################################################################

	### Instance alias for the like-named class method.
	def message( *msgs )
		self.class.message( *msgs )
	end


	### Instance-alias for the like-named class method
	def ansiCode( *attributes )
		self.class.ansiCode( *attributes )
	end


	### Instance alias for the like-named class method
	def debugMsg( *msgs )
		self.class.debugMsg( *msgs )
	end


	### Return a separator line made up of <tt>length</tt> of the specified
	### <tt>char</tt>.
	def hrule( length=75, char="-" )
		return (char * length ) + "\n"
	end

	### Return a section delimited by hrules with the specified +caption+ and
	### +content+.
	def hruleSection( content, caption='' )
		caption << ' ' unless caption.empty?
		return caption +
			hrule( 75 - caption.length ) +
			content.chomp + "\n" +
			hrule()
	end


	### Output a header for delimiting tests
	def printTestHeader( desc )
		return unless $VERBOSE || $DEBUG
		message "%s>>> %s <<<%s" % 
			[ ansiCode('bold','yellow','on_blue'), desc, ansiCode('reset') ]
	end


	#################################################################
	###	T E S T I N G   U T I L I T I E S
	#################################################################

	### Try to force garbage collection to start.
	def collectGarbage
		a = []
		1000.times { a << {} }
		a = nil
		GC.start
	end


	### Touch a file and truncate it to 0 bytes
	def zerofile( filename )
		File.open( filename, File::WRONLY|File::CREAT ) {}
		File.truncate( filename, 0 )
	end


	### Output the name of the test as it's running if in verbose mode.
	def run( result )
		$stderr.puts self.name if $VERBOSE || $DEBUG

		# Support debugging for individual tests
		olddb = nil
		if $DebugPattern && $DebugPattern =~ @method_name
			Arrow::Logger.global.outputters <<
				Arrow::Logger::Outputter.create( 'file:stderr' )
			Arrow::Logger.global.level = :debug

			olddb = $DEBUG
			$DEBUG = true
		end
		
		super

		unless olddb.nil?
			$DEBUG = olddb 
			Arrow::Logger.global.outputters.clear
		end
	end


	#################################################################
	###	P R O M P T I N G   M E T H O D S
	#################################################################

	### Output the specified <tt>promptString</tt> as a prompt (in green) and
	### return the user's input with leading and trailing spaces removed.
	def prompt( promptString )
		promptString.chomp!
		return readline( ansiCode('bold', 'green') + "#{promptString}: " +
						 ansiCode('reset') ).strip
	end


	### Prompt the user with the given <tt>promptString</tt> via #prompt,
	### substituting the given <tt>default</tt> if the user doesn't input
	### anything.
	def promptWithDefault( promptString, default )
		response = prompt( "%s [%s]" % [ promptString, default ] )
		if response.empty?
			return default
		else
			return response
		end
	end

end # module Arrow

