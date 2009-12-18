#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'spec'

require 'apache/fakerequest'
require 'arrow'
require 'arrow/template/iterator'

require 'spec/lib/helpers'
require 'spec/lib/constants'


include Arrow::TestConstants


#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::Template::Iterator do
	include Arrow::SpecHelpers

	TEST_ITERATOR_ITEMS = [
		"Achomawi", 
		"Chemakum", 
		"Chukchansi", 
		"Clayoquot", 
		"Coast Salish", 
		"Cowichan", 
		"Haida", 
		"Hupa", 
		"Hesquiat", 
		"Karok", 
		"Klamath", 
		"Koskimo", 
		"Kwakiutl", 
		"Lummi", 
		"Makah", 
		"Nootka", 
		"Puget Sound Salish", 
		"Quileute", 
		"Quinault", 
		"Shasta", 
		"Skokomish", 
		"Tolowa", 
		"Tututni", 
		"Willapa", 
		"Wiyot", 
		"Yurok",
	]


	it "can be constructed with unsplatted arrays" do
		Arrow::Template::Iterator.new( @items ).items.should == @items
	end
	

	it "can be constructed with a splatted list" do
		Arrow::Template::Iterator.new( :fii, :baq, :bax ).items.should == [:fii, :baq, :bax]
	end
	

	before( :each ) do
		@items = TEST_ITERATOR_ITEMS.dup
		@iter = Arrow::Template::Iterator.new( @items )
	end
	

	it "is enumerable" do
		@iter.map {|iter, item| item }.should == @items
	end


	it "knows which is the first iteration" do
		@iter.find {|iter, item| iter.first? }.last.should == @items.first
	end


	it "knows which is the last iteration" do
		@iter.find {|iter, item| iter.last? }.last.should == @items.last
	end


	it "knows how to break out of the iteration" do
		stuff = []

		@iter.each do |iter, item|
			break if iter.iteration >= @items.length / 2
			stuff << item
		end

		stuff.should == @items[ 0, @items.length / 2 ]
	end


	it "knows how to skip iterations" do
		stuff = []

		@iter.each do |iter, item|
			stuff << item
			iter.skip
		end

		expected = []
		@items.each_with_index do |item, i|
			expected << item if ( i % 2 ).zero?
		end
		
		stuff.should == expected
	end
	
	
	it "knows how to skip backwards" do
		stuff = []

		@iter.each do |iter, item|
			stuff << item
			iter.skip( -2 ) if iter.last? && stuff.length == @items.length
		end

		expected = @items + @items[-2,2]

		stuff.should == expected
	end
	
	
	it "knows if the previous iteration skipped one or more items" do
		stuff = []

		@iter.each do |iter, item|
			if iter.first?
				iter.skip
			elsif iter.skipped?
				stuff << :skipped
			end
			stuff << item
		end

		expected = @items.dup
		expected[0,2] = [:skipped]
		
		stuff.should == expected
	end
	

	it "knows how to redo an iterations" do
		stuff = []

		@iter.each do |iter, item|
			stuff << item
			iter.redo if stuff.length == 1
		end

		stuff.should == [ @items.first ] + @items
	end


	it "can restart the iteration" do
		stuff = []
		@iter.each do |iter, item|
			stuff << item
			iter.restart if iter.last? && stuff.length <= @items.length
		end

		stuff.should == @items + @items
	end


	it "knows if its iteration is even" do
		stuff = []
		@iter.each do |iter, item|
			if iter.even?
				stuff << item
			else
				stuff << :odd
			end
		end

		expected = @items.inject([]) {|a,i| a << ((a.length % 2).nonzero? ? :odd : i); a }
		stuff.should == expected
	end


	it "knows if its iteration is odd" do
		stuff = []
		@iter.each do |iter, item|
			if iter.odd?
				stuff << item
			else
				stuff << :even
			end
		end

		expected = @items.inject([]) {|a,i| a << ((a.length % 2).zero? ? :even : i); a }
		stuff.should == expected
	end
	

	it "can produce 'even' or 'odd' depending on whether the iteration is even or odd" do
		stuff = []
		@iter.each do |iter, item|
			stuff << iter.even_or_odd
		end

		expected = @items.inject([]) {|a,i| a << ((a.length % 2).zero? ? 'even' : 'odd'); a }
		stuff.should == expected
	end
	
end


# vim: set nosta noet ts=4 sw=4:
