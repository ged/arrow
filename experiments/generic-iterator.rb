#!/usr/bin/env ruby
# 
# The Arrow::Template::Iterator class, instances of which can
# be used to provide an iteration context to nodes in an Arrow template.
# 
# Lots of the ideas for this class were stolen/influenced in no small way by Hal
# Fulton's "super-iterator" post to the Ruby-talk ML [ruby-talk: 46337].
#
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#

require 'arrow/exceptions'
require 'arrow/path'
require 'arrow/template'

### Iterator class for reflecting on the state of enumerable template 
### directives.
class Arrow::Template::Iterator < Arrow::Object
	include Enumerable

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$
	


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Template::Iterator object that wraps the given
	### +iter+ (a Method object) and passing the specified +parameters+ for
	### iteration.
	def initialize( iter, *parameters )
		raise TypeError, "wrapped object must respond to #call" unless
			iter.respond_to?( :call )

		@iter		= iter
		@parameters	= parameters

		@iteration	= nil
		@args		= []
		@lastItem	= nil
		@item		= nil
		@iterating	= false
		@skipped	= false
		@marker		= nil
	end


	######
	public
	######

	# The Method object the iterator will use for iteration
	attr_reader :iter

	# The parameters that will be passed to the method the iterator is
	# wrapping when it is called.
	attr_reader :parameters

	# The arguments to the current iteration
	attr_reader :args

	# The index of the current iteration
	attr_accessor :iteration

	# The item previous to the currently iterated one. If this is the first
	# iteration, this will be +nil+.
	attr_reader :lastItem


	### The primary iteration interface.
	def iterate( &innerBlock )
		raise LocalJumpError, "no block given" unless innerBlock

		origIter = @iter or
			raise LocalJumpError, "no iteration method?!"
		origParameters = @parameters

		begin
			# Save this point so #restart can jump back here later. This is in a
			# loop because it needs to be remade after it's used the first time.
			until @marker
				self.log.debug "Setting restart marker"
				@marker = callcc {|cc| cc}
			end
			@iterating = true
			@iteration = 0
			rvals = []

			# Mark the outer loop for #break
			self.log.debug "Entering :break catch/throw"
			catch( :break ) do
				lastItem = nil
				skips = 0

				self.log.debug "Calling wrapped iter"
				@iter.call( *@parameters ) {|*args|
					@args = args
					self.log.debug "In iteration %d: got args: %p" %
					[ @iteration, @args ]

					# If this iteration is being skipped, don't call the inner
					# block.
					if ( skips.nonzero? )
						# Set the skipped flag for next iteration and decrement
						# the number of skips that are left.
						self.log.debug "Skipping; skips = %p" % skips
						@skipped = skips.nonzero?
						skips -= 1
					else
						# Catch a skip with the number of items to
						# skip. Unskipped iterations "skip" 0 items.
						self.log.debug "Entering :skip catch/throw"
						skips = catch( :skip ) {
							self.log.debug "Calling inner block"
							rvals << innerBlock.call( self, *args )
							0
						}
					end

					@iteration += 1
					@lastArgs = args
				}

			end

			return rvals
		ensure
			@parameters	= origParameters
			@iter		= origIter
			@iteration	= nil
			@args		= []
			@lastItem	= nil
			@item		= nil
			@iterating	= false
			@skipped	= false
			@marker		= nil
		end
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
	

end # class Iterator
