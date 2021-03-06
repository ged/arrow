#!/usr/bin/env ruby

require 'arrow/exceptions'
require 'arrow/path'
require 'arrow/template'

# The Arrow::Template::Iterator class, instances of which can
# be used to provide an iteration context to nodes in an Arrow template.
# 
# Lots of the ideas for this class were stolen/influenced in no small way by Hal
# Fulton's "super-iterator" post to the Ruby-talk ML [ruby-talk: 46337].
#
# == Examples
#
#   ### Render the directive's bracketed nodes once for each item in the
#   ### iterated content.
#   def render_subnodes( attribute, template, scope )
#       res = []
#   
#       iterator = Arrow::Template::Iterator.new( attribute )
#       iterator.each {|iter,*blockArgs|
#   
#           # Process the nodes
#           template.with_overridden_attributes( scope, 'iterator' => iter ) {|template|
#               res << template.render( @subnodes, scope )
#           }
#       }
#   
#       return *res
#   end
#
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Template::Iterator < Arrow::Object
	include Enumerable



	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Template::Iterator object for the given +items+.
	def initialize( *items )
		if items.length == 1 && items[0].is_a?( Enumerable )
			@items = items[0]
		else
			@items = items
		end

		@iteration = nil
		@lastItem  = nil
		@item 	   = nil
		@nextItem  = nil
		@iterating = false
		@skipped   = false
		@marker    = nil
	end


	######
	public
	######

	# The list of items in this iteration
	attr_accessor :items

	# The index of the current iteration
	attr_accessor :iteration

	# The item previous to the currently iterated one. If this is the first
	# iteration, this will be +nil+.
	attr_reader :lastItem

	# The item which succeeds the currently iterated one. If this is the
	# last iteration, this will be +nil+.
	attr_reader :nextItem


	### The primary iteration interface.
	def each
		items = @items.dup
		@items = @items.entries
		raise LocalJumpError, "no block given" unless block_given?

		#self.log.debug "Iterating over @items = %p" % [ @items ]

		# Save this point so #restart can jump back here later. This is in a
		# loop because it needs to be remade after it's used the first time.
		until @marker
			@marker = callcc {|cc| cc}
		end
		@iterating = true
		@iteration = 0

		# Mark the outer loop for #break
		catch( :break ) {
			until @iteration >= @items.length

				# Catch a skip with the number of items to skip. Unskipped
				# iterations "skip" 0 items.
				n = catch( :skip ) {
					@lastItem	= self.first? ? nil : @items[ @iteration - 1 ]
					@item		= @items[ @iteration ]
					@nextItem	= self.last? ? nil : @items[ @iteration + 1 ]

					if @item.is_a?( Array )
						yield( self, *@item )
					else
						yield( self, @item )
					end

					0
				}

				# Set the skipped flag for next iteration if we're skipping
				@skipped = n.nonzero?
				@iteration += n + 1
			end
		}

		#self.log.debug "Returning from Iterator#each"

		return @items
	ensure
		@items		= items
		@iteration	= nil
		@lastItem	= nil
		@item		= nil
		@nextItem	= nil
		@iterating	= false
		@skipped	= false
		@marker		= nil
	end


	### Cause the next +n+ items to be skipped
	def skip( n=1 )
		# Jump back into #each with the number of iterations to skip
		throw( :skip, n ) if @iterating
	end


	### Redo the current iteration
	def redo
		throw( :skip, -1 ) if @iterating
	end


	### Cause iteration to immediately terminate, ala the 'break' keyword
	def break
		# Jump back into the outer loop of #each 
		throw( :break ) if @iterating
	end


	### Cause iteration to begin over again
	def restart
		# Call back into the continuation that was saved at the beginning of
		# #each
		@marker.call if @iterating
	end


	### Returns +true+ if the last iteration skipped one or more items.
	def skipped?
		@skipped
	end


	### Returns +true+ if the current iteration is the first one.
	def first?
		return @iteration == 0
	end


	### Returns either "even" if the iteration is in even-numbered iteration, or "odd".
	def even_or_odd
		return self.odd? ? "odd" : "even"
	end
	

	### Returns +true+ if the current iteration is an odd-numbered
	### iteration.
	def odd?
		return @iterating && ( @iteration % 2 ).nonzero?
	end


	### Return +true+ if the current iteration is an even-numbered
	### iteration.
	def even?
		return !self.odd?
	end


	### Returns +true+ if the current iteration is the last one.
	def last?
		return @iteration == @items.length - 1
	end


end # class Arrow::Template::Iterator

