#!/usr/bin/ruby
#
# An attempt to make a miminal test case for the weird LocalJumpError that's
# happening in Arrow::Iterator.
# 
# Time-stamp: <16-Jan-2004 10:02:22 deveiant>
#

class Foo
	def initialize( &block )
		@block = block
	end

	attr_accessor :block

	def run( &innerBlock )
		puts "In Foo#run"
		self.block.call {|*args|
			puts "In the wrapped iterator's block"
			innerBlock.call( *args )
		}
	end
end

ary = (1..20).to_a
puts "Creating a Foo"
obj = Foo::new( &ary.method(:each) )
puts "Running the Foo"
obj.run {|*args|
	puts "callback for the inner block with args: %p" % args
}
puts "Done with the Foo"

# Produces:
#   Creating a Foo
#   Running the Foo
#   In Foo#run
#   0: no block given (LocalJumpError)
