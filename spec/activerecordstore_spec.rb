#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'digest/md5'
	require 'spec/runner'
	require 'arrow'
	require 'arrow/session/activerecordstore'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

module ActiveRecord
	class RecordNotFound < StandardError
	end
end
# test class to override with partial mocks:
class ARTestClass
end
# other test modules and classes for the string to class conversion:
module Testy
	class McTest
	end
end

class MyOutie
	class MyInnie
	end
end

module Firsty
	module Secondy
		class Thirdy
		end
	end
end
#####################################################################
###	C O N T E X T S
#####################################################################

# so we have a plugin
# the plugin gets the argument passed in as the first argument to new,
# and the id object as the second argument.
# so we could make a context for that:
context "An ActiveRecord Store plugin" do

	specify "can use activerecord:ClassName as a URI" do
		@class_uri = 'activerecord:ARTestClass'
		@mock_id = mock("id")
		@mock_id.should_receive(:new?).once.and_return(true)

		lambda {
			arstore = Arrow::Session::ActiveRecordStore.new(@class_uri, @mock_id)
			arstore.klass.should == ARTestClass
		}.should_not_raise

	end

	specify "can use activerecord:ModuleName::ClassName as a URI" do
		@class_uri = 'activerecord:Testy::McTest'
		@mock_id = mock("id")
		@mock_id.should_receive(:new?).once.and_return(true)

		lambda {
			arstore = Arrow::Session::ActiveRecordStore.new(@class_uri, @mock_id)
			arstore.klass.should == Testy::McTest
		}.should_not_raise
	end

	specify "can use activerecord:ClassName::ClassName as a URI" do
		@class_uri = 'activerecord:MyOutie::MyInnie'
		@mock_id = mock("id")
		@mock_id.should_receive(:new?).once.and_return(true)

		lambda {
			arstore = Arrow::Session::ActiveRecordStore.new(@class_uri, @mock_id)
			arstore.klass.should == MyOutie::MyInnie
		}.should_not_raise
	end

	specify "can use activerecord:ModuleName::ModuleName::ClassName as a URI" do
		@class_uri = 'activerecord:Firsty::Secondy::Thirdy'
		@mock_id = mock("id")
		@mock_id.should_receive(:new?).once.and_return(true)

		lambda {
			arstore = Arrow::Session::ActiveRecordStore.new(@class_uri, @mock_id)
			arstore.klass.should == Firsty::Secondy::Thirdy
		}.should_not_raise
	end

end

context "A new ActiveRecord Store plugin" do

	setup do
		@class_uri = 'activerecord:ARTestClass'
		
		@mock_id = mock("id")
		@mock_id.should_receive(:new?).once.and_return(true)
		@arstore = Arrow::Session::ActiveRecordStore.new(@class_uri, @mock_id)
	end

	specify "can have data inserted into it" do
		@session_id = '9823u42jlkfs9823'
		@arstore['foo'] = 'bar'
		@mock_id.should_receive(:to_s).exactly(3).times.and_return(@session_id)
		@mock_data_object = mock("ar_dataobject")
		@mock_data_object.should_receive(:session_id=).once.with(@session_id)
		@mock_data_object.should_receive(:session_data=).once
		@mock_data_object.should_receive(:save).once.and_return(true)
		ARTestClass.should_receive(:find).once.and_raise(ActiveRecord::RecordNotFound)
		ARTestClass.should_receive(:new).once.and_return(@mock_data_object)
		lambda {
			@arstore.insert
		}.should_not_raise
	end

	specify "will raise an exception if it cannot save the insert" do
		@session_id = '9823u42jlkfs9823'
		@arstore['foo'] = 'bar'
		@mock_id.should_receive(:to_s).exactly(3).times.and_return(@session_id)
		@errors = mock("errors")
		@errors.should_receive(:full_messages).once
		@mock_data_object = mock("ar_dataobject")
		@mock_data_object.should_receive(:session_id=).once.with(@session_id)
		@mock_data_object.should_receive(:session_data=).once
		@mock_data_object.should_receive(:save).once.and_return(false)
		@mock_data_object.should_receive(:errors).once.and_return( @errors )
		ARTestClass.should_receive(:find).once.and_raise(ActiveRecord::RecordNotFound)
		ARTestClass.should_receive(:new).once.and_return(@mock_data_object)
		lambda {
			@arstore.insert
		}.should_raise(Arrow::SessionError)
	end

	specify "can have it's data updated" do
		@session_id = '9823u42jlkfs9823'
		@arstore['foo'] = 'bar'
		@mock_id.should_receive(:to_s).twice.and_return(@session_id)
		@mock_data_object = mock("ar_dataobject")
		@mock_data_object.should_receive(:session_data=).once
		@mock_data_object.should_receive(:save).once.and_return(true)
		ARTestClass.should_receive(:find).once.with(@session_id).
			and_return(@mock_data_object)
		lambda {
			@arstore.update
		}.should_not_raise
	end

	specify "will raise an exception if it cannot have it's data updated" do
		@session_id = '9823u42jlkfs9823'
		@arstore['foo'] = 'bar'
		@mock_id.should_receive(:to_s).twice.and_return(@session_id)
		@errors = mock("errors")
		@errors.should_receive(:full_messages).once
		@mock_data_object = mock("ar_dataobject")
		@mock_data_object.should_receive(:session_data=).once
		@mock_data_object.should_receive(:save).once.and_return(false)
		@mock_data_object.should_receive(:errors).once.and_return( @errors )
		ARTestClass.should_receive(:find).once.with(@session_id).
			and_return(@mock_data_object)
		lambda {
			@arstore.update
		}.should_raise(Arrow::SessionError)
	end

	specify "can return data stored with it" do
		@session_id = '9823u42jlkfs9823'
		@mock_id.should_receive(:to_s).twice.and_return(@session_id)
		@mock_data_object = mock("ar_dataobject")
		@mock_data_object.should_receive(:session_data).once.and_return("")
		ARTestClass.should_receive(:find).once.with(@session_id).
			and_return(@mock_data_object)
		
		lambda {
			@arstore.retrieve
		}.should_not_raise
	end

	specify "can remove the session data completely" do
		@session_id = '9823u42jlkfs9823'
		@mock_id.should_receive(:to_s).twice.and_return(@session_id)
		@mock_data_object = mock("ar_dataobject")
		ARTestClass.should_receive(:delete).once.with(@session_id).and_return(true)
		lambda {
			@arstore.remove
		}.should_not_raise
		
	end
end

# vim: set nosta noet ts=4 sw=4:
