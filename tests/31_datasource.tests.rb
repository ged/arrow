#!/usr/bin/ruby -w
#
# Unit test for the DataSource class
# $Id: 31_datasource.tests.rb,v 1.1 2004/02/29 02:55:38 stillflame Exp $
#
# Copyright (c) 2004 RubyCrafters, LLC. Most rights reserved.
# 
# This work is licensed under the Creative Commons Attribution-ShareAlike
# License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/1.0/ or send a letter to Creative
# Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
#
# 

unless defined? Arrow::TestCase
	testsdir = File::dirname( File::expand_path(__FILE__) )
	basedir = File::dirname( testsdir )
	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/tests/lib" unless
		$LOAD_PATH.include?( "#{basedir}/tests/lib" )

	require 'arrowtestcase'
end

require 'arrow/datasource'

### Collection of tests for the DataSource class.
class DataSourceTestCase < Arrow::TestCase

	DataSource = Arrow::DataSource
 
	### :MC: These tests all assume a lot of familiarity with some particular
	### data target.
	Type = "mysql"
	Command = "mysql"
	Database = "test"
    Host = "localhost"
    Table = "test"
    User = "stillflame"
    Password = "0000"
	testsdir = File::dirname( File::expand_path(__FILE__) )
	InitFile = "#{testsdir}/test_data.sql"
	TestSource = "#{Type}://#{User}:#{Password}@#{Host}/#{Database}/#{Table}"

	### :MC: Initialize the database
	### :MG: Ick.
	if ENV['USER'] == 'stillflame'
		`#{Command} -p#{Password} -u#{User} -h#{Host} #{Database} < #{InitFile}`
	end

	### :MG: Since only Martin can run these tests, skip all of them if the
	### person running them isn't him.
	def setup
		skip( "These tests only work if you're Martin" ) unless 
			ENV['USER'] == 'stillflame'
	end


	#################################################################
	###	T E S T S
	#################################################################

	### Instance test
	def test_00_Instantiate
		test = nil
		assert_nothing_raised				{ test = DataSource.new(TestSource) }
		assert								test
		assert_kind_of						DataSource, test
	end


	def test_10_Retrieval 
		test = DataSource.new(TestSource)
		count = nil
		assert_nothing_raised				{ count = test.count }
		assert_equal						1, count
		result = nil
		assert_nothing_raised				{ result = test.new({:bar => "meow"}) }
		assert								result
		assert_kind_of						test, result
		assert_nothing_raised				{ result = test[1] }
		assert								result
		assert_kind_of						test, result
	end


	def test_20_Save 
		test = DataSource.new(TestSource)
		before_count = test.count
		result = test.new({:bar => "meow"})
		assert_nothing_raised				{result.save}
		assert								result[:id]
		assert_equal						before_count + 1, test.count
	end



end

