#!/usr/bin/ruby
# 
# This file contains the Arrow::Session::ActiveRecordStore class, a derivative of
# Arrow::Session::Store. Instances of this class store a session object as a
# row via an ActiveRecord database abstraction.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Jeremiah Jordan <phaedrus@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'arrow/exceptions'
require 'arrow/session/store'
require 'yaml'

class Arrow::Session::ActiveRecordStore < Arrow::Session::Store
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	attr_reader :klass

	def initialize(klass_uri, idobj)
		klass_string = klass_uri.to_s
		klass_string.gsub!(/activerecord:/, '')
#		sections = klass_string.split('::')
#		klass_name = sections.pop
#		sections.each
#		@klass = Kernel.const_get(klass_string)
		@klass = find_constant(Kernel, klass_string)
		super
	end

	def insert
		super {|data|
			@instance = nil
			begin
				@instance = @klass.find( @id.to_s )
			rescue ActiveRecord::RecordNotFound
				@instance = @klass.new
			end
			@instance.session_id = @id.to_s  # we get @id from the parent class
			@instance.session_data = data 
			unless(@instance.save)
				raise Arrow::SessionError, 
				      "Could not save session %p" % @instance.errors.full_messages,
			          caller
			end
		}
	end

	def update
		super {|data|
			@instance = @klass.find( @id.to_s )
			@instance.session_data = data 
			unless(@instance.save)
				raise Arrow::SessionError,
				      "Could not save session %p" % @instance.errors.full_messages,
			          caller
			end
		}
	end

	def retrieve
		super {
			session_data = []
			@instance = nil
			begin
				@instance = @klass.find( @id.to_s )
				session_data = @instance.session_data
			rescue ActiveRecord::RecordNotFound
#				return []
			end

			session_data
		}
	end

	def remove
		super
		@klass.delete(@id.to_s)
	end

	protected

    def serialized_data
      @data.to_yaml
    end

    def serialized_data=( data )
      @data = YAML::load( data )
    end


	private
	def find_constant( module_const, string )
		# simplest case, string contains just a class
		unless(string.match(/::/))
			return module_const.const_get(string)
		else
			sections = string.split(/::/)
			next_module = sections.shift
			return find_constant(
				module_const.const_get(next_module), 
				sections.join('::'))
		end
	end

end
