#!/usr/bin/ruby

# This is an experiment to see if you can use module ivars from including
# classes.

module Foo
	def self::included( mod )
		mod.module_eval {
			@registry = {}
			class << self
				attr_accessor :registry
			end
		}
	end
end


class Bar
	include Foo

	def self::preg
		self.registry
	end

end



puts "Trying to p the registry from the included module..."
p Bar::preg
puts "done."

