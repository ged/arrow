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
#   validator = Arrow::FormValidator::new
#	validator.validate( req_params, profile )
#
#	# Now if there weren't any errors, send the success page
#	if validator.okay?
#		return success_template
#
#	# Otherwise fill in the error template with auto-generated error messages
#	# and return that instead.
#	else
#		failure_template.errors( validator.errorMessages )
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


module Arrow

### Add some Hash-ish methods for convenient access to FormValidator#valid.
class FormValidator < ::FormValidator
	extend Forwardable
	
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$


	### Create a new Arrow::FormValidator object.
	def initialize( profile=nil )
		super
		@descriptions = {}
	end


	######
	public
	######

	# Hash of field descriptions
	attr_reader :descriptions

	### Delegate Hash methods to the valid form variables hash
	def_delegators :@form,
		*(Hash::public_instance_methods(false) - ['[]', '[]=', 'inspect'])


	### Validate the input in +params+ against the given +profile+. Overridden
	### because the original chokes on unknown fields.
	def validate( params, profile )
		@descriptions = profile.delete( :descriptions ) || {}
		super
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


	### Returns +true+ if any fields are missing or contain invalid values.
	def errors?
		return !self.okay?
	end


	### Return +true+ if all required fields were present and validated
	### correctly.
	def okay?
		self.missing.empty? && self.invalid.empty?
	end


	### Return an error message for each missing or invalid field; if
	### +includeUnknown+ is +true+, also include messages for unknown fields.
	def errorMessages( includeUnknown=false )
		msgs = []
		self.missing.each do |field|
			desc = @descriptions[ field.to_s.intern ] || field
			msgs << "Missing required field '#{desc}'"
		end

		self.invalid.each do |field, constraint|
			desc = @descriptions[ field.to_s.intern ] || field
			msgs << "Invalid value for field '#{desc}'"
		end

		if includeUnknown
			self.unknown.each do |field|
				desc = @descriptions[ field.to_s.intern ] || field
				msgs << "Unknown field '#{desc}'"
			end
		end

		return msgs
	end


	# Returns a distinct list of missing fields. Overridden to eliminate the
	# "undefined method `<=>' for :foo:Symbol" error.
	def missing
		@missing_fields.uniq.sort_by {|f| f.to_s}
	end
	
	# Returns a distinct list of unknown fields.
	def unknown
		(@unknown_fields - @invalid_fields.keys).uniq.sort_by {|f| f.to_s}
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

end # class FormValidator
end # module Arrow


