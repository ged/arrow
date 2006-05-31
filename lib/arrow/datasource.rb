#!/usr/bin/ruby
# 
# This file contains the Arrow::DataSource class, an experimental implementation
# of an abstract data layer for Arrow. It's not ready for real use yet.
# 
# == Synopsis
# 
#   
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# * Martin Chase <stillflame@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file docs/COPYRIGHT for licensing details.
#

require 'cgi'
require 'yaml'

require 'arrow'
require 'arrow/exceptions'

### Instance of this class The data abstraction layer..
class Arrow::DataSource < Arrow::Object

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	@@source_types = {}

	#################
	# Class Methods #
	#################

	### Creates a new object of the class specified by the url provided.
	def self.new(string)
		type, source = string.split('//')
		type.downcase!
		if @@source_types[type]
			@@source_types[type].new(source)
		else
			raise Arrow::TypeError.new("Unknown data source type '%s'" % type)
		end
	end

	### Registers the class as a valid type to create objects as.
	def self.inherited(klass)
		@@source_types[klass.name.downcase] = klass
	end

	######
	public
	######

	### The source string which identified this DataSource.
	attr_reader :source

	### Test to see if two DataSource's can be used in place of each other.
	def ==(other)
		(self.singleton_methods.sort) == (other.singleton_methods.sort)
	end

	### Convert the DataSource object into a DataSource::TestData object.
	### This will create a new TestData object each time it is called, to
	### within a second.
	def make_test(name = Time.now.to_i)
		TestData.create(self, name)
	end


	### Locally-stored mock data to be used for testing purposes.
	class TestData < Arrow::DataSource

		### Class methods for TestData.
		class << self

			### The path where all stored TestData objects are located.  Note
			### that this isn't useful by default.
			attr_accessor :data_path

			### Loads a test data file given by the name provided.
			def load(name)
				if File.exists?(name)
				elsif File.exists?(File.join(self.data_path, name))
					name = File.join(self.data_path, name)
				else
					raise Arrow::LoadError.new( "No such testdata file to load: '%s'" % name )
				end
				data = nil
				File.open(name) {|file|
					data = file.read
				}
				obj = Yaml.load(data)
			end
			alias :[] :load

			### Turns a normal DataSource object into a TestData object
			def create(source, name)
				testdata = self.new(source.source, name)
				source.singleton_methods.each {|meth|
					next if /=/.match(meth)
					testdata.instance_eval <<-EVAL
						def #{meth}; @#{meth}; end
						def #{meth}=(o); @#{meth} = o; end
					EVAL
					obj = source.send(meth)
					testdata.send(meth+"=", obj)
				}
			end

			private :new

		end # class << self

		self.data_path = ''

		### The identifier string for the data being copied.
		attr :real_source

		### Creates a new TestData object with the given identifier, and
		### either loads the pre-existing data from disk, or creates it.
		def initialize(source, name)
			@real_source = source
			@source = source + "/" + name
		end

		### Saves the test data to the data directory.
		def save 
			name = File.join(TestData.data_path,@source)
			File.new(name, "w") {|file|
				file.write(@data.to_yaml)
			}
		end

	end # class TestData
end # class Arrow::DataSource
