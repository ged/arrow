#!/usr/bin/ruby
# This is a minimal test case for the bug which causes RDoc to get confused by a
# conditional used in assignment to a constant (I think). This is the "file"
# documentation.

# This is the class documentation.
class Foo

	Bar = if true
			  "foo"
		  end


	def aMethod( *args )
		puts "something"
	end
end

