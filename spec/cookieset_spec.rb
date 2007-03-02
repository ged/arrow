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
	require 'arrow/cookieset'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


#####################################################################
###	C O N T E X T S
#####################################################################

context "A CookieSet object" do
	setup do
		@cookieset = Arrow::CookieSet.new
	end


	specify "is able to enummerate over each cookie in the set" do
		pants_cookie = Arrow::Cookie.new( 'pants', 'baggy' )
		shirt_cookie = Arrow::Cookie.new( 'shirt', 'pirate' )
		@cookieset << shirt_cookie << pants_cookie
		
		cookies = []
		@cookieset.each do |cookie|
			cookies << cookie
		end
		
		cookies.length.should == 2
		cookies.should_include( pants_cookie )
		cookies.should_include( shirt_cookie )
	end

	specify "is able to add a cookie referenced symbolically" do
		pants_cookie = Arrow::Cookie.new( 'pants', 'denim' )
		@cookieset[:pants] = pants_cookie
		@cookieset['pants'].should == pants_cookie
	end
	

	specify "autos-create a cookie for a non-cookie passed to the index setter" do
		lambda { @cookieset['bar'] = 'badgerbadgerbadgerbadger' }.should_not_raise

		@cookieset['bar'].should_be_an_instance_of( Arrow::Cookie )
		@cookieset['bar'].value.should == 'badgerbadgerbadgerbadger'
	end

	specify "raises an exception if the name of a cookie being set doesn't agree with the key it being set with" do
		pants_cookie = Arrow::Cookie.new( 'pants', 'corduroy' )
		lambda { @cookieset['shirt'] = pants_cookie }.should_raise( ArgumentError )
	end

	specify "implements Enumerable" do
		Enumerable.instance_methods( false ).each do |meth|
			@cookieset.should_respond_to( meth )
		end
	end

	specify "is able to set a cookie's value symbolically to something other than a String" do
		@cookieset[:wof] = Digest::MD5.hexdigest( Time.now.to_s )
	end
	
	specify "is able to set a cookie with a Symbol key" do
		@cookieset[:wof] = Arrow::Cookie.new( :wof, "something" )
	end
	
end

context "A CookieSet created with an Array of cookies" do
	specify "should flatten that array" do
		cookie_array = []
		cookie_array << Arrow::Cookie.new( 'foo', 'bar' )
		cookie_array << [Arrow::Cookie.new( 'shmoop', 'torgo!' )]
		
		cookieset = nil
		lambda {cookieset = Arrow::CookieSet.new(cookie_array)}.should_not_raise
		cookieset.length.should == 2
	end
end

context "A CookieSet with a 'foo' cookie" do
	setup do
		@cookie = Arrow::Cookie.new( 'foo', 'bar' )
		@cookieset = Arrow::CookieSet.new( @cookie )
	end
	
	specify "contains only one cookie" do
		@cookieset.length.should == 1
	end
	
	specify "is able to return the 'foo' Arrow::Cookie via its index operator" do
		@cookieset[ 'foo' ].should == @cookie
	end


	specify "is able to return the 'foo' Arrow::Cookie via its symbolic name" do
		@cookieset[ :foo ].should == @cookie
	end

	specify "knows if it includes a cookie named 'foo'" do
		@cookieset.should_include( 'foo' )
	end

	specify "knows if it includes a cookie referenced by :foo" do
		@cookieset.should_include( :foo )
	end
	
	specify "knows that it doesn't contain a cookie named 'lollypop'" do
		@cookieset.should_not_include( 'lollypop' )
	end
	
	specify "knows that it includes the 'foo' cookie object" do
		@cookieset.should_include( @cookie )
	end
	
	
	specify "adds a cookie to the set if it has a different name" do
		new_cookie = Arrow::Cookie.new( 'bar', 'foo' )
		@cookieset << new_cookie
		
		@cookieset.length.should == 2
		@cookieset.should_include( new_cookie )
	end


	specify "replaces any existing same-named cookie added via appending" do
		new_cookie = Arrow::Cookie.new( 'foo', 'giant scallops of doom' )
		@cookieset << new_cookie
		
		@cookieset.length.should == 1
		@cookieset.should_include( new_cookie )
		@cookieset['foo'].should == new_cookie
	end

	specify "replaces any existing same-named cookie set via the index operator" do
		new_cookie = Arrow::Cookie.new( 'foo', 'giant scallops of doom' )
		@cookieset[:foo] = new_cookie
		
		@cookieset.length.should == 1
		@cookieset.should include( new_cookie )
		@cookieset['foo'].should equal( new_cookie )
	end

end

# vim: set nosta noet ts=4 sw=4:
