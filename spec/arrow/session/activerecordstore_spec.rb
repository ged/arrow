#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'digest/md5'
	require 'spec/runner'
	require 'apache/fakerequest'
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

describe Arrow::Session::ActiveRecordStore, " (class)" do

	it "knows how to load a data class from an 'activerecord:ClassName' URI" do
		uri = URI.parse('activerecord:ARTestClass')
		id = Arrow::Session::SHA1Id.new( uri, '/test' )

		lambda {
			arstore = Arrow::Session::ActiveRecordStore.new( uri, id )
			arstore.klass.should == ARTestClass
		}.should_not raise_error()
	end

	it "knows how to load a data class from an 'activerecord:ModuleName::ClassName' URI" do
		uri = URI.parse('activerecord:Testy::McTest')
		id = Arrow::Session::SHA1Id.new( uri, '/test' )

		lambda {
			arstore = Arrow::Session::ActiveRecordStore.new( uri, id )
			arstore.klass.should == Testy::McTest
		}.should_not raise_error()
	end

	it "knows how to load a data class from an 'activerecord:ClassName::ClassName' URI" do
		uri = URI.parse('activerecord:MyOutie::MyInnie')
		id = Arrow::Session::SHA1Id.new( uri, '/test' )

		lambda {
			arstore = Arrow::Session::ActiveRecordStore.new( uri, id )
			arstore.klass.should == MyOutie::MyInnie
		}.should_not raise_error()
	end

	it "knows how to load a data class from an 'activerecord:ModuleName::ModuleName::ClassName' URI" do
		uri = URI.parse('activerecord:Firsty::Secondy::Thirdy')
		id = Arrow::Session::SHA1Id.new( uri, '/test' )

		lambda {
			arstore = Arrow::Session::ActiveRecordStore.new( uri, id )
			arstore.klass.should == Firsty::Secondy::Thirdy
		}.should_not raise_error()
	end

end

describe Arrow::Session::ActiveRecordStore do

	before(:each) do
		uri = URI.parse('activerecord:ARTestClass')
		@id = Arrow::Session::SHA1Id.new( uri, '/test' )

		@arclassmock = mock( "ActiveRecord class" )
		@arstore = Arrow::Session::ActiveRecordStore.new( uri, @id )
		@arstore.instance_variable_set( :@klass, @arclassmock )
	end


	it "fetches existing session data from the database" do
		dataobj = mock( "ar_dataobject" )
		@arclassmock.should_receive( :find_or_create_by_session_id ).with( @id.to_s ).
			and_return( dataobj )
		dataobj.should_receive( :new_record? ).and_return( false )
		dataobj.should_receive( :session_data ).and_return( :session_data )
		
		@arstore.retrieve
	end

	it "creates a new session data hash if the session doesn't already exist in the database" do
		dataobj = mock( "ar_dataobject" )
		@arclassmock.should_receive( :find_or_create_by_session_id ).with( @id.to_s ).
			and_return( dataobj )
		dataobj.should_receive( :new_record? ).and_return( true )
		dataobj.should_receive( :session_data= ).with( {} )
		dataobj.should_receive( :session_data ).and_return( :session_data )
		
		@arstore.retrieve
	end

	it "writes session data back to the database when updated" do
		dataobj = mock( "ar_dataobject" )
		dataobj.should_receive( :new_record? ).and_return( false )
		dataobj.should_receive( :session_data= ).once
		dataobj.should_receive( :save ).once.and_return( true )
		dataobj.should_receive( :lock_version ).and_return( 18 )

		@arclassmock.should_receive( :find_or_create_by_session_id ).with( @id.to_s ).
			and_return( dataobj )

		@arstore.update
	end
	
	it "will raise an exception if it cannot save the session" do
		
		errors_mock = mock("errors")
		errors_mock.should_receive(:full_messages).once.and_return(['malformed data'])

		dataobj = mock( "ar_dataobject" )
		dataobj.should_receive( :new_record? ).and_return( false )
		dataobj.should_receive( :session_data= ).once.with( {} )
		dataobj.should_receive( :save ).once.and_return( false )
		dataobj.should_receive( :errors ).once.and_return( errors_mock )
		dataobj.should_receive( :lock_version ).and_return( 18 )

		@arclassmock.should_receive( :find_or_create_by_session_id ).with( @id.to_s ).
			and_return( dataobj )

		lambda { @arstore.insert }.should raise_error( Arrow::SessionError, /malformed data/ )
	end
	
	it "removes the corresponding record in the database when deleted" do
		@arclassmock.should_receive( :delete ).with( @id.to_s )
		@arstore.remove
	end
end

# vim: set nosta noet ts=4 sw=4:
