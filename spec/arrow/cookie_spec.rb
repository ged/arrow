#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec'
	require 'spec/lib/helpers'
	require 'apache/fakerequest'
	require 'arrow/cookie'
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

describe Arrow::Cookie do
	include Arrow::SpecHelpers

	before( :all ) do
		setup_logging( :debug )
	end

	after( :all ) do
		reset_logging()
	end


	it "parses a 'nil' Cookie header field as an empty Hash" do
		Arrow::Cookie.parse(nil).should == {}
	end

	it "parses a empty string Cookie header field as an empty Hash" do
		Arrow::Cookie.parse('').should == {}
	end

	it "parses a cookie header field with a single value as a cookie with a single value" do
		result = Arrow::Cookie.parse( 'a=b' )
		result.should be_an_instance_of( Hash )
		result.should have(1).member
		result['a'].should be_an_instance_of( Arrow::Cookie )
		result['a'].name.should == 'a'
		result['a'].value.should == 'b'
		result['a'].values.should == ['b']
	end

	it "parses a cookie header field with a cookie with multiple values as a cookie with multiple values" do
		result = Arrow::Cookie.parse( 'a=b&c' )
		result.should be_an_instance_of( Hash )
		result.should have(1).member
		result['a'].should be_an_instance_of( Arrow::Cookie )
		result['a'].name.should == 'a'
		result['a'].value.should == 'b'
		result['a'].values.should == ['b', 'c']
	end

	it "parses a cookie header field with multiple cookies and multiple values" do
		result = Arrow::Cookie.parse( 'a=b&c; f=o&o' )
		result.should be_an_instance_of( Hash )
		result.should have(2).members
		result['a'].should be_an_instance_of( Arrow::Cookie )
		result['a'].name.should == 'a'
		result['a'].value.should == 'b'
		result['a'].values.should == ['b', 'c']
		result['f'].should be_an_instance_of( Arrow::Cookie )
		result['f'].name.should == 'f'
		result['f'].value.should == 'o'
		result['f'].values.should == ['o', 'o']
	end

	def test_parse_two_multi_value_cookies_should_return_two_cookies_with_multiple_values
		rval = nil

		assert_nothing_raised do
			rval = Arrow::Cookie.parse( "a=b&c; f=o&o" )
		end

		assert_instance_of Hash, rval
		assert_equal 2, rval.length

		cookie = rval['a']
		assert_instance_of Arrow::Cookie, cookie
		assert_equal "a", cookie.name
		assert_equal "b", cookie.value
		assert_equal ["b", "c"], cookie.values

		cookie = rval['f']
		assert_instance_of Arrow::Cookie, cookie
		assert_equal "f", cookie.name
		assert_equal "o", cookie.value
		assert_equal ["o", "o"], cookie.values
	end


	def test_parse_with_empty_value_should_return_cookie_nonetheless
		rval = nil

		assert_nothing_raised do
			rval = Arrow::Cookie.parse( "a=" )
		end

		assert_instance_of Hash, rval
		assert_equal 1, rval.length

		cookie = rval['a']
		assert_instance_of Arrow::Cookie, cookie
		assert_equal "a", cookie.name
		assert_equal nil, cookie.value
		assert_equal [], cookie.values
	end


	def test_parse_with_version_should_set_version
		rval = nil

		assert_nothing_raised do
			rval = Arrow::Cookie.parse( %{$Version=1; a="b"} )
		end

		assert_instance_of Hash, rval
		assert_equal 1, rval.length, "should be one cookie"

		cookie = rval['a']
		assert_instance_of Arrow::Cookie, cookie
		assert_equal "a", cookie.name
		assert_equal "b", cookie.value
		assert_equal ["b"], cookie.values

		assert_equal 1, cookie.version, "cookie version should be 1"
	end


	def test_parse_with_path_should_set_path
		rval = nil

		assert_nothing_raised do
			rval = Arrow::Cookie.parse( %{a=b; $Path=/arrow} )
		end

		assert_instance_of Hash, rval
		assert_equal 1, rval.length, "should be one cookie"

		cookie = rval['a']
		assert_instance_of Arrow::Cookie, cookie
		assert_equal "a", cookie.name
		assert_equal "b", cookie.value
		assert_equal ["b"], cookie.values

		assert_equal "/arrow", cookie.path, "cookie path should be /arrow"

	end

	def test_parse_with_domain_should_set_domain
		rval = nil

		assert_nothing_raised do
			rval = Arrow::Cookie.parse( %{a=b; $domain=rubycrafters.com} )
		end

		assert_instance_of Hash, rval
		assert_equal 1, rval.length, "should be one cookie"

		cookie = rval['a']
		assert_instance_of Arrow::Cookie, cookie
		assert_equal "a", cookie.name
		assert_equal "b", cookie.value
		assert_equal ["b"], cookie.values

		assert_equal ".rubycrafters.com", cookie.domain,
		 	"cookie domain should be '.rubycrafters.com'"
	end

	def test_parse_with_invalid_cookie_name_doesnt_error
		rval = nil
		assert_nothing_raised do
			rval = Arrow::Cookie.parse( "{a}=foo" )
		end

		assert_instance_of Hash, rval
		assert_equal 0, rval.length
	end

	def test_to_s_with_single_value_generates_valid_cookie
		rval = nil
		assert_nothing_raised do
			rval = @cookie.to_s
		end

		assert_equal %{by_rickirac=9917eb}, rval
	end

	def test_to_s_with_multiple_values_generates_valid_cookie
		rval = nil
		@cookie.values += ["brer lapin"]
		assert_nothing_raised do
			rval = @cookie.to_s
		end

		assert_equal %{by_rickirac=9917eb&brer%20lapin}, rval
	end

	def test_to_s_adds_version_for_versions_other_than_0
		rval = nil
		@cookie.version = 1
		assert_nothing_raised do
			rval = @cookie.to_s
		end

		assert_equal %{by_rickirac=9917eb; Version=1}, rval
	end

	def test_explicitly_specified_domain_must_always_start_with_a_dot
		rval = nil
		@cookie.domain = "foo.com"
		assert_nothing_raised do
			rval = @cookie.to_s
		end

		assert_equal %{by_rickirac=9917eb; Domain=.foo.com}, rval
	end

	def test_domain_eq_shouldnt_prepend_a_dot_if_it_already_has_one
		rval = nil
		@cookie.domain = ".rubycrafters.com"
		assert_nothing_raised do
			rval = @cookie.to_s
		end
		assert_equal %{by_rickirac=9917eb; Domain=.rubycrafters.com}, rval
	end

	def test_value_with_semicolon_is_escaped
		rval = nil
		@cookie.values += [%{"modern technology"; ain't it a paradox?}]
		assert_nothing_raised do
			rval = @cookie.to_s
		end

		assert_equal %{by_rickirac=9917eb&%22modern%20technology} +
			%{%22%3B%20ain't%20it%20a%20paradox%3F}, rval
	end

	def test_expires_value_is_in_correct_format
		rval = nil
		now = Time.now
		nowstring = now.gmtime.strftime( "%a, %d-%b-%Y %H:%M:%S GMT" )
		@cookie.expires = now

		assert_nothing_raised do
			rval = @cookie.to_s
		end

		assert_include nowstring, rval
	end

	def test_cookies_with_the_same_name_should_be_considered_equal
		other_cookie = Arrow::Cookie.new( "by_rickirac", "something else" )
		assert @cookie.eql?( other_cookie ), 
			"%p should be eql? to %p" % [ @cookie, other_cookie ]
	end

	def test_cookie_expire_bang_should_set_the_expiration_date_to_a_time_in_the_past
		assert_nothing_raised do
			@cookie.expire!
		end

		expiration = @cookie.expires
		assert expiration < Time.now - (25 * 60)
	end


	def test_cookie_hash_should_use_the_hash_of_the_cookies_name
		assert_equal @cookie.name.hash, @cookie.hash
	end
end

# vim: set nosta noet ts=4 sw=4:
