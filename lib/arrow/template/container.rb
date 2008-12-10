#!/usr/bin/env ruby

require 'forwardable'

require 'arrow/exceptions'
require 'arrow/path'

# The Arrow::Template::Container class, a derivative of
# Arrow::Object. Instances of this class are stateful containers for
# ContainerDirective nodes .
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#
class Arrow::Template::Container < Arrow::Object
	extend Forwardable
	include Enumerable

	# SVN Revision
	SVNRev = %q$Rev$
	
	# SVN Id
	SVNId = %q$Id$
	
	# The methods of collections which are delegated to their contents Array
	DelegatedMethods = 
		( (Array.instance_methods(false) | Enumerable.instance_methods(false)) -
		  %w{<<} )

	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Template::Container object with the given +name+
	### and +contents+.
	def initialize( name, *contents )
		@name = name
		@contents = contents

		@sortblock = nil
		@filters = []

		super()
	end



	######
	public
	######

	# Delegate index methods to contents
	def_delegators :@contents, *DelegatedMethods

	# The contents of the container
	attr_accessor :contents

	# The name of the container
	attr_reader :name

	# The Array of transform functions applied to this container at render
	# time, in the order in which they will be applied.
	attr_reader :filters

	# The sort block associated with the container.
	attr_reader :sortblock


	### Add the given object/s to this container.
	def <<( object )
		@contents << object
		return self
	end


	### Add the specified filter +block+ to the container. When the
	### container is used in a render, the filter block will be called once
	### for each contained object and whatever it returns will be used
	### instead of the original.
	def addFilter( &block )
		@filters << block
	end

	
	### Add the specified sort +block+ to the container. When the container
	### is used in a render, its contents will be used in the order returned
	### from the sort block.
	def setSort( &block )
		@sortblock = block
	end


	### Iterate over the contents of this container after applying filters,
	### sort blocks, etc. to them.
	def each( &block )
		raise LocalJumpError, "no block given" unless block_given?

		contents = @contents.dup
		contents.sort!( &@sortblock ) if @sortblock
		@filters.each {|filter|
			contents = contents.collect( &filter )
		}

		Arrow::Template::Iterator.new( *contents ).each( &block )
	end


	### Return the last value to be set in this container
	def last
		@contents.last
	end

end # class Arrow::Template::Container


