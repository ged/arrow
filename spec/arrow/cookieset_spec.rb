#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'digest/md5'
	require 'spec'
	require 'apache/fakerequest'
	require 'arrow'
	require 'arrow/cookieset'
rescue LoadError
	unless Object.const_defined?( :Gem )
				retry
	end
	raise
end


#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::CookieSet do
	before(:each) do
		@cookieset = Arrow::CookieSet.new
	end


	it "is able to enummerate over each cookie in the set" do
		pants_cookie = Arrow::Cookie.new( 'pants', 'baggy' )
		shirt_cookie = Arrow::Cookie.new( 'shirt', 'pirate' )
		@cookieset << shirt_cookie << pants_cookie

		cookies = []
		@cookieset.each do |cookie|
			cookies << cookie
		end

		cookies.length.should == 2
		cookies.should include( pants_cookie )
		cookies.should include( shirt_cookie )
	end

	it "is able to add a cookie referenced symbolically" do
		pants_cookie = Arrow::Cookie.new( 'pants', 'denim' )
		@cookieset[:pants] = pants_cookie
		@cookieset['pants'].should == pants_cookie
	end


	it "autos-create a cookie for a non-cookie passed to the index setter" do
		lambda { @cookieset['bar'] = 'badgerbadgerbadgerbadger' }.should_not raise_error()

		@cookieset['bar'].should be_an_instance_of( Arrow::Cookie )
		@cookieset['bar'].value.should == 'badgerbadgerbadgerbadger'
	end

	it "raises an exception if the name of a cookie being set doesn't agree with the key it being set with" do
		pants_cookie = Arrow::Cookie.new( 'pants', 'corduroy' )
		lambda { @cookieset['shirt'] = pants_cookie }.should raise_error( ArgumentError )
	end

	it "implements Enumerable" do
		Enumerable.instance_methods( false ).each do |meth|
			@cookieset.should respond_to( meth )
		end
	end

	it "is able to set a cookie's value symbolically to something other than a String" do
		@cookieset[:wof] = Digest::MD5.hexdigest( Time.now.to_s )
	end

	it "is able to set a cookie with a Symbol key" do
		@cookieset[:wof] = Arrow::Cookie.new( :wof, "something" )
	end

end

describe Arrow::CookieSet, " created with an Array of cookies" do
	it "should flatten the array" do
		cookie_array = []
		cookie_array << Arrow::Cookie.new( 'foo', 'bar' )
		cookie_array << [Arrow::Cookie.new( 'shmoop', 'torgo!' )]

		cookieset = nil
		lambda {cookieset = Arrow::CookieSet.new(cookie_array)}.should_not raise_error()
		cookieset.length.should == 2
	end
end

describe Arrow::CookieSet, " with a 'foo' cookie" do
	before(:each) do
		@cookie = Arrow::Cookie.new( 'foo', 'bar' )
		@cookieset = Arrow::CookieSet.new( @cookie )
	end

	it "contains only one cookie" do
		@cookieset.length.should == 1
	end

	it "is able to return the 'foo' Arrow::Cookie via its index operator" do
		@cookieset[ 'foo' ].should == @cookie
	end


	it "is able to return the 'foo' Arrow::Cookie via its symbolic name" do
		@cookieset[ :foo ].should == @cookie
	end

	it "knows if it includes a cookie named 'foo'" do
		@cookieset.should include( 'foo' )
	end

	it "knows if it includes a cookie referenced by :foo" do
		@cookieset.should include( :foo )
	end

	it "knows that it doesn't contain a cookie named 'lollypop'" do
		@cookieset.should_not include( 'lollypop' )
	end

	it "knows that it includes the 'foo' cookie object" do
		@cookieset.should include( @cookie )
	end


	it "adds a cookie to the set if it has a different name" do
		new_cookie = Arrow::Cookie.new( 'bar', 'foo' )
		@cookieset << new_cookie

		@cookieset.length.should == 2
		@cookieset.should include( new_cookie )
	end


	it "replaces any existing same-named cookie added via appending" do
		new_cookie = Arrow::Cookie.new( 'foo', 'giant scallops of doom' )
		@cookieset << new_cookie

		@cookieset.length.should == 1
		@cookieset.should include( new_cookie )
		@cookieset['foo'].should equal( new_cookie )
	end

	it "replaces any existing same-named cookie set via the index operator" do
		new_cookie = Arrow::Cookie.new( 'foo', 'giant scallops of doom' )
		@cookieset[:foo] = new_cookie

		@cookieset.length.should == 1
		@cookieset.should include( new_cookie )
		@cookieset['foo'].should equal( new_cookie )
	end

end

# vim: set nosta noet ts=4 sw=4:
