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
	require 'arrow/session/sha1id'
	require 'arrow/session/activerecordstore'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

### Testing classes

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
		uri = URI.parse('activerecord:ARTestClass')
		id = Arrow::Session::SHA1Id.new( uri, '/test' )

		lambda {
			arstore = Arrow::Session::ActiveRecordStore.new( uri, id )
			arstore.klass.should == ARTestClass
		}.should_not_raise
	end

	specify "can use activerecord:ModuleName::ClassName as a URI" do
		uri = URI.parse('activerecord:Testy::McTest')
		id = Arrow::Session::SHA1Id.new( uri, '/test' )

		lambda {
			arstore = Arrow::Session::ActiveRecordStore.new( uri, id )
			arstore.klass.should == Testy::McTest
		}.should_not_raise
	end

	specify "can use activerecord:ClassName::ClassName as a URI" do
		uri = URI.parse('activerecord:MyOutie::MyInnie')
		id = Arrow::Session::SHA1Id.new( uri, '/test' )

		lambda {
			arstore = Arrow::Session::ActiveRecordStore.new( uri, id )
			arstore.klass.should == MyOutie::MyInnie
		}.should_not_raise
	end

	specify "can use activerecord:ModuleName::ModuleName::ClassName as a URI" do
		uri = URI.parse('activerecord:Firsty::Secondy::Thirdy')
		id = Arrow::Session::SHA1Id.new( uri, '/test' )

		lambda {
			arstore = Arrow::Session::ActiveRecordStore.new( uri, id )
			arstore.klass.should == Firsty::Secondy::Thirdy
		}.should_not_raise
	end

end

context "A new ActiveRecord session store" do

	setup do
		uri = URI.parse('activerecord:ARTestClass')
		@id = Arrow::Session::SHA1Id.new( uri, '/test' )

		@arclassmock = mock( "ActiveRecord class" )
		@arstore = Arrow::Session::ActiveRecordStore.new( uri, @id )
		@arstore.instance_variable_set( :@klass, @arclassmock )
	end


	specify "fetches existing session data from the database" do
		mock_data_object = mock( "ar_dataobject" )
		@arclassmock.should_receive( :find_or_create_by_session_id ).with( @id.to_s ).
			and_return( mock_data_object )
		mock_data_object.should_receive( :new_record? ).and_return( false )
		mock_data_object.should_receive( :session_data ).and_return( :session_data )
		
		@arstore.retrieve
	end

	specify "creates a new session data hash if the session doesn't already exist in the database" do
		mock_data_object = mock( "ar_dataobject" )
		@arclassmock.should_receive( :find_or_create_by_session_id ).with( @id.to_s ).
			and_return( mock_data_object )
		mock_data_object.should_receive( :new_record? ).and_return( true )
		mock_data_object.should_receive( :session_data= ).with( {} )
		mock_data_object.should_receive( :session_data ).and_return( :session_data )
		
		@arstore.retrieve
	end

	specify "writes session data back to the database when updated" do
		mock_data_object = mock( "ar_dataobject" )
		mock_data_object.should_receive( :new_record? ).and_return( false )
		mock_data_object.should_receive( :session_data= ).once
		mock_data_object.should_receive( :create_or_update ).once.and_return( true )

		@arclassmock.should_receive( :find_or_create_by_session_id ).with( @id.to_s ).
			and_return( mock_data_object )

		@arstore.update
	end
	
	specify "will raise an exception if it cannot save the session" do
		
		errors_mock = mock("errors")
		errors_mock.should_receive(:full_messages).once.and_return(['malformed data'])

		mock_data_object = mock( "ar_dataobject" )
		mock_data_object.should_receive( :new_record? ).and_return( false )
		mock_data_object.should_receive( :session_data= ).once.with( {} )
		mock_data_object.should_receive( :create_or_update ).once.and_return( false )
		mock_data_object.should_receive( :errors ).once.and_return( errors_mock )

		@arclassmock.should_receive( :find_or_create_by_session_id ).with( @id.to_s ).
			and_return( mock_data_object )

		lambda { @arstore.insert }.should_raise( Arrow::SessionError, /malformed data/ )
	end
	
	specify "removes the corresponding record in the database when deleted" do
		@arclassmock.should_receive( :delete ).with( @id.to_s )
		@arstore.remove
	end
end

# vim: set nosta noet ts=4 sw=4:
