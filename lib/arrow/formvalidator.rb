#!/usr/bin/ruby
# 
# This file contains the Arrow::FormValidator class, a derivative of
# FormValidator. A FormValidator variant that adds some nicities and additional
# validations.
# 
# == Usage
#
#   require 'arrow/formvalidator'
#
#	# Profile specifies validation criteria for input
#	profile = {
#     :required		=> :name,
#     :optional		=> [:email, :description],
#     :filters		=> [:strip, :squeeze],
#     :untaint_all_constraints => true,
#     :descriptions	=> {
#     	:email			=> "Customer Email",
#     	:description	=> "Issue Description",
#     	:name			=> "Customer Name",
#     },
#     :constraints	=> {
#     	:email	=> :email,
#     	:name	=> /^[\x20-\x7f]+$/,
#     	:description => /^[\x20-\x7f]+$/,
#     },
#	}
#
#	# Create a validator object and pass in a hash of request parameters and the
#	# profile hash.
#   validator = Arrow::FormValidator.new
#	validator.validate( req_params, profile )
#
#	# Now if there weren't any errors, send the success page
#	if validator.okay?
#		return success_template
#
#	# Otherwise fill in the error template with auto-generated error messages
#	# and return that instead.
#	else
#		failure_template.errors( validator.error_messages )
#		return failure_template
#	end
#
# == Rcsid
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
# Portions of this file are from Ruby on Rails' CGIMethods class from the
# action_controller:
#   
#   Copyright (c) 2004 David Heinemeier Hansson
#   
#   Permission is hereby granted, free of charge, to any person obtaining
#   a copy of this software and associated documentation files (the
#   "Software"), to deal in the Software without restriction, including
#   without limitation the rights to use, copy, modify, merge, publish,
#   distribute, sublicense, and/or sell copies of the Software, and to
#   permit persons to whom the Software is furnished to do so, subject to
#   the following conditions:
#   
#   The above copyright notice and this permission notice shall be
#   included in all copies or substantial portions of the Software.
#   
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
#   LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
#   OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
#   WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#   
# 
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'forwardable'
require 'formvalidator'

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/object'

# Override to eliminate use of deprecated Object#type
module FormValidator::ConstraintHelpers # :nodoc:
    def do_constraint(key, constraints)
		constraints.each do |constraint|
			case constraint
			when String
				apply_string_constraint(key, constraint)
			when Hash
				apply_hash_constraint(key, constraint)
			when Proc
				apply_proc_constraint(key, constraint)
			when Regexp
				apply_regexp_constraint(key, constraint) 
			end
		end
    end
end

### Add some Hash-ish methods for convenient access to FormValidator#valid.
class Arrow::FormValidator < ::FormValidator
	extend Forwardable
	include Arrow::Loggable
	
	
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	Defaults = {
		:descriptions => {},
	}


	### Create a new Arrow::FormValidator object.
	def initialize( profile, params=nil )
		@profile = Defaults.merge( profile )
		validate( params ) if params
	end


	######
	public
	######

	### Delegate Hash methods to the valid form variables hash
	def_delegators :@form,
		*(Hash.public_instance_methods(false) - ['[]', '[]=', 'inspect'])


	### Hash of field descriptions
	def descriptions
		@profile[:descriptions]
	end


	### Set hash of field descriptions
	def descriptions=( new_descs )
		@profile[:descriptions] = new_descs
	end


	### Validate the input in +params+. If the optional +additional_profile+ is
	### given, merge it with the validator's default profile before validating.
	def validate( params, additional_profile=nil )
		if additional_profile
			self.log.debug "Merging additional profile %p" % [additional_profile]
			@profile.merge!( additional_profile ) 
		end

		super( params, @profile )
	end


	### Overridden to remove the check for extra keys.
	def check_profile_syntax( profile )
	end


	### Index operator; fetch the validated value for form field +key+.
	def []( key )
		@form[ key.to_s ]
	end


	### Index assignment operator; set the validated value for form field +key+
	### to the specified +val+.
	def []=( key, val )
		@form[ key.to_s ] = val
	end


	### Returns +true+ if there were no arguments given.
	def empty?
		return @form.empty?
	end


	### Returns +true+ if there were arguments given.
	def args?
		return !@form.empty?
	end


	### Returns +true+ if any fields are missing or contain invalid values.
	def errors?
		return !self.okay?
	end


	### Return +true+ if all required fields were present and validated
	### correctly.
	def okay?
		self.missing.empty? && self.invalid.empty?
	end


	### Return an array of field names which had some kind of error associated
	### with them.
	def error_fields
		return self.missing | self.invalid.keys
	end
	

	### Return an error message for each missing or invalid field; if
	### +includeUnknown+ is +true+, also include messages for unknown fields.
	def error_messages( includeUnknown=false )
		self.log.debug "Building error messages from descriptions: %p" %
			[ @profile[:descriptions] ]
		msgs = []
		self.missing.each do |field|
			desc = @profile[:descriptions][ field.to_s ] || field
			msgs << "Missing value for '#{desc}'"
		end

		self.invalid.each do |field, constraint|
			desc = @profile[:descriptions][ field.to_s ] || field
			msgs << "Invalid value for field '#{desc}'"
		end

		if includeUnknown
			self.unknown.each do |field|
				desc = @profile[:descriptions][ field.to_s ] || field
				msgs << "Unknown field '#{desc}'"
			end
		end

		return msgs
	end


	### Returns a distinct list of missing fields. Overridden to eliminate the
	### "undefined method `<=>' for :foo:Symbol" error.
	def missing
		@missing_fields.uniq.sort_by {|f| f.to_s}
	end
	
	### Returns a distinct list of unknown fields.
	def unknown
		(@unknown_fields - @invalid_fields.keys).uniq.sort_by {|f| f.to_s}
	end


	### Returns the valid fields after expanding Rails-style
	### 'customer[address][street]' variables into multi-level hashes.
	def valid
		if @parsed_params.nil?
			@parsed_params = {}
			valid = super()

			for key, value in valid
				value = [value] if key =~ /.*\[\]$/
				unless key.include?( '[' )
					@parsed_params[ key ] = value
				else
					build_deep_hash( value, @parsed_params, get_levels(key) )
				end
			end
		end

		return @parsed_params
	end


	### Constraint methods
	
	### Constrain a value to +true+ and +false+.
	def match_boolean( val )
		rval = nil
		if ( val =~ /^(t(?:rue)?|y(?:es)?)$/i )
			rval = true
		elsif ( val =~ /^(no?|f(?:alse)?)$/i )
			rval = false
		end
		
		return rval
	end


	# Applies a builtin constraint to form[key]
	def apply_string_constraint(key, constraint)
		# FIXME: multiple elements
		res = self.__send__( "match_#{constraint}", @form[key].to_s )
		unless res.nil?
			@form[key] = res 
			if untaint?(key)
				@form[key].untaint
			end
		else
			@form.delete(key)
			@invalid_fields[key] ||= []
			unless @invalid_fields[key].include?(constraint)
				@invalid_fields[key].push(constraint) 
			end
			nil
		end
	end


	#######
	private
	#######

	### Overridden to eliminate use of default #to_a (deprecated)
	def strify_array( array )
		array = [ array ] if !array.is_a?( Array )
		array.map do |m|
			m = (Array === m) ? strify_array(m) : m
			m = (Hash === m) ? strify_hash(m) : m
			Symbol === m ? m.to_s : m
		end
	end


	### Build a deep hash out of the given parameter +value+
	def build_deep_hash( value, hash, levels )
		if levels.length == 0
			value
		elsif hash.nil?
			{ levels.first => build_deep_hash(value, nil, levels[1..-1]) }
		else
			hash.update({ levels.first => build_deep_hash(value, hash[levels.first], levels[1..-1]) })
		end
	end


	### Get the number of hash levels in the specified +key+
	### Stolen from the CGIMethods class in Rails' action_controller.
	PARAMS_HASH_RE = /^([^\[]+)(\[.*\])?(.)?.*$/
	def get_levels( key )
		all, main, bracketed, trailing = PARAMS_HASH_RE.match( key ).to_a
		if main.nil?
			return []
		elsif trailing
			return [key]
		elsif bracketed
			return [main] + bracketed.slice(1...-1).split('][')
		else
			return [main]
		end
	end

end # class Arrow::FormValidator


