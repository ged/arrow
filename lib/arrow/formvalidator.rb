#!/usr/bin/env ruby

require 'uri'
require 'forwardable'
require 'date'
require 'formvalidator'

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/object'

# A FormValidator variant that adds some convenience methods and additional validations.
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
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#
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
#--
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#
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

	attr_reader :raw_form
	

	### Delegate Hash methods to the valid form variables hash
	def_delegators :@form,
		*(Hash.public_instance_methods(false) - ['[]', '[]=', 'inspect'])


	### Stringified description of the validator
	def to_s
		""
	end

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
		@raw_form = params.dup
		profile = @profile
		
		if additional_profile
			self.log.debug "Merging additional profile %p" % [additional_profile]
			profile = @profile.merge( additional_profile ) 
		end

		super( params, profile )
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
	alias_method :has_errors?, :errors?


	### Return +true+ if all required fields were present and validated
	### correctly.
	def okay?
		self.missing.empty? && self.invalid.empty?
	end
	
	
	### Returns +true+ if the given +field+ is one that should be untainted.
	def untaint?( field )
		self.log.debug "Checking to see if %p should be untainted." % [field]
		rval = ( @untaint_all || @untaint_fields.include?(field) )
		if rval
			self.log.debug "  ...yep it should."
		else
			self.log.debug "  ...nope."
		end
		
		return rval
	end
	


	### Return an array of field names which had some kind of error associated
	### with them.
	def error_fields
		return self.missing | self.invalid.keys
	end


	### Get the description for the specified field.
	def get_description( field )
		return @profile[:descriptions][ field.to_s ] if
			@profile[:descriptions].key?( field.to_s )
		
		desc = field.to_s.
			gsub( /.*\[(\w+)\]/, "\\1" ).
			gsub( /_(.)/ ) {|m| " " + m[1,1].upcase }.
			gsub( /^(.)/ ) {|m| m.upcase }
		return desc
	end
	

	### Return an error message for each missing or invalid field; if
	### +includeUnknown+ is +true+, also include messages for unknown fields.
	def error_messages( include_unknown=false )
		self.log.debug "Building error messages from descriptions: %p" %
			[ @profile[:descriptions] ]
		msgs = []
		self.missing.each do |field|
			msgs << "Missing value for '%s'" % self.get_description( field )
		end

		self.invalid.each do |field, constraint|
			msgs << "Invalid value for '%s'" % self.get_description( field )
		end

		if include_unknown
			self.unknown.each do |field|
				msgs << "Unknown parameter '%s'" % self.get_description( field )
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
	
	### Constrain a value to +true+ (or +yes+) and +false+ (or +no+).
	def match_boolean( val )
		rval = nil
		if ( val =~ /^(t(?:rue)?|y(?:es)?)|1$/i )
			rval = true
		elsif ( val =~ /^(no?|f(?:alse)?)|0$/i )
			rval = false
		end
		
		return rval
	end


	### Constrain a value to an integer
	def match_integer( val )
		return Integer( val ) rescue nil
	end
	

	### Contrain a value to a Float
	def match_float( val )
		return Float( val ) rescue nil
	end
	
	
	### Constrain a value to a parseable Date
	def match_date( val )
		return Date.parse( val ) rescue nil
	end
	
	
	### Constrain a value to alpha characters (a-z, case-insensitive)
	def match_alpha( val )
		if val =~ /^([a-z]+)$/i
			return $1
		else
			return nil
		end
	end
	
	
	### Constrain a value to alpha characters (a-z, case-insensitive and 0-9)
	def match_alphanumeric( val )
		if val =~ /^([a-z0-9]+)$/i
			return $1
		else
			return nil
		end
	end
	
	
	### Constrain a value to any printable characters
	def match_printable( val )
		if val =~ /^([[:print:][:space:]]{0,255})$/
			return val
		else
			return nil
		end
	end
	
	
	
	#
	# RFC822 Email Address Regex
	# --------------------------
	# 
	# Originally written by Cal Henderson
	# c.f. http://iamcal.com/publish/articles/php/parsing_email/
	#
	# Translated to Ruby by Tim Fletcher, with changes suggested by Dan Kubb.
	#
	# Licensed under a Creative Commons Attribution-ShareAlike 2.5 License
	# http://creativecommons.org/licenses/by-sa/2.5/
	# 
	RFC822_EMAIL_ADDRESS = begin
		qtext = '[^\\x0d\\x22\\x5c\\x80-\\xff]'
		dtext = '[^\\x0d\\x5b-\\x5d\\x80-\\xff]'
		atom = '[^\\x00-\\x20\\x22\\x28\\x29\\x2c\\x2e\\x3a-' +
			'\\x3c\\x3e\\x40\\x5b-\\x5d\\x7f-\\xff]+'
		quoted_pair = '\\x5c[\\x00-\\x7f]'
		domain_literal = "\\x5b(?:#{dtext}|#{quoted_pair})*\\x5d"
		quoted_string = "\\x22(?:#{qtext}|#{quoted_pair})*\\x22"
		domain_ref = atom
		sub_domain = "(?:#{domain_ref}|#{domain_literal})"
		word = "(?:#{atom}|#{quoted_string})"
		domain = "#{sub_domain}(?:\\x2e#{sub_domain})*"
		local_part = "#{word}(?:\\x2e#{word})*"
		addr_spec = "#{local_part}\\x40#{domain}"
		/\A#{addr_spec}\z/
	end
	
	### Override the parent class's definition to (not-sloppily) match email 
	### addresses.
	def match_email( val )
		match = RFC822_EMAIL_ADDRESS.match( val )
		self.log.debug "Validating an email address %p: %p" %
			[ val, match ]
		return match ? match[0] : nil
	end
	
	
	RFC1738Hostname = begin
		alphadigit = /[a-z0-9]/i
		# toplabel		 = alpha | alpha *[ alphadigit | "-" ] alphadigit
		toplabel = /[a-z]((#{alphadigit}|-)*#{alphadigit})?/i
		# domainlabel	 = alphadigit | alphadigit *[ alphadigit | "-" ] alphadigit
		domainlabel = /#{alphadigit}((#{alphadigit}|-)*#{alphadigit})?/i
		# hostname		 = *[ domainlabel "." ] toplabel
		hostname = /\A(#{domainlabel}\.)*#{toplabel}\z/
	end

	### Match valid hostnames according to the rules of the URL RFC.
	def match_hostname( val )
		match = RFC1738Hostname.match( val )
		return match ? match[0] : nil
	end


	### Match valid URIs
	def match_uri( val )
		return URI.parse( val )
	rescue URI::InvalidURIError => err
		self.log.error "Error trying to parse URI %p: %s" % [ val, err.message ]
		return nil
	rescue NoMethodError
		self.log.debug "Ignoring bug in URI#parse"
		return nil
	end
	

	### Apply one or more +constraints+ to the field value/s corresponding to
	### +key+.
	def do_constraint( key, constraints )
		constraints.each do |constraint|
			case constraint
			when String
				apply_string_constraint( key, constraint )
			when Hash
				apply_hash_constraint( key, constraint )
			when Proc
				apply_proc_constraint( key, constraint )
			when Regexp
				apply_regexp_constraint( key, constraint ) 
			else
				raise "unknown constraint type %p" % [constraint]
			end
		end
	end


	### Applies a builtin constraint to form[key].
	def apply_string_constraint( key, constraint )
		# FIXME: multiple elements
		rval = self.__send__( "match_#{constraint}", @form[key].to_s )
		self.log.debug "Tried a string constraint: %p: %p" %
			[ @form[key].to_s, rval ]
		self.set_form_value( key, rval, constraint )
	end
	
	
	### Apply a constraint given as a Hash to the value/s corresponding to the
	### specified +key+:
	### 
	### constraint::
	###   A builtin constraint (as a Symbol; e.g., :email), a Regexp, or a Proc.
	### name::
	###   A description of the constraint should it fail and be listed in #invalid.
	### params::
	###   If +constraint+ is a Proc, this field should contain a list of other
	###   fields to send to the Proc.
	def apply_hash_constraint( key, constraint )
		action = constraint["constraint"]
		
		rval = case action
			when String
				self.apply_string_constraint( key, action )
			when Regexp
				self.apply_regexp_constraint( key, action )
			when Proc
				if args = constraint["params"]
					args.collect! {|field| @form[field] }
					self.apply_proc_constraint( key, action, *args )
				else
					self.apply_proc_constraint( key, action )
				end
			end
	
		# If the validation failed, and there's a name for this constraint, replace
		# the name in @invalid_fields with the name
		if !rval && constraint["name"]
			@invalid_fields[key] = constraint["name"]
		end
	
		return rval
	end
	
	
	### Apply a constraint that was specified as a Proc to the value for the given 
	### +key+
	def apply_proc_constraint( key, constraint, *params )
		value = nil
	
		unless params.empty?
			value = constraint.call( *params )
		else
			value = constraint.call( @form[key] )
		end
	
		self.set_form_value( key, value, constraint )
	end
	
	
	### Applies regexp constraint to form[key]
	def apply_regexp_constraint( key, constraint )
		self.log.debug "Validating '%p' via regexp %p" % [@form[key], constraint]

		if match = constraint.match( @form[key].to_s )
			self.log.debug "  matched %p" % [match[0]]

			if match.captures.empty?
				self.log.debug "  no captures, using whole match: %p" % [match[0]]
				self.set_form_value( key, match[0], constraint )
			elsif match.captures.length == 1
				self.log.debug "  extracting one capture: %p" % [match.captures.first]
				self.set_form_value( key, match.captures.first, constraint )
			else
				self.log.debug "  extracting multiple captures: %p" % [match.captures]
				self.set_form_value( key, match.captures, constraint )
			end
		else
			self.set_form_value( key, nil, constraint )
		end
	end
	
	
	### Set the form value for the given +key+. If +value+ is false, add it to
	### the list of invalid fields with a description derived from the specified
	### +constraint+.
	def set_form_value( key, value, constraint )
		key.untaint
	
		if !value.nil? 
			self.log.debug "Setting form value for %p to %p (constraint was %p)" %
				[ key, value, constraint ]
			@form[key] = value
			@form[key].untaint if self.untaint?( key )
			return true
			
		else
			self.log.debug "Clearing form value for %p (constraint was %p)" %
				[ key, constraint ]
			@form.delete( key )
			@invalid_fields ||= {}
			@invalid_fields[ key ] ||= []
	
			unless @invalid_fields[ key ].include?( constraint )
				@invalid_fields[ key ].push( constraint )
			end
			return false
		end
	end


	### Formvalidator hack:
	### The formvalidator filters method has a bug where he assumes an array
	###	 when it is in fact a string for multiple values (ie anytime you have a 
	###	 text-area with newlines in it).
	def filters
		@filters_array = Array(@profile[:filters]) unless(@filters_array)
		@filters_array.each do |filter|

			if respond_to?( "filter_#{filter}" )
				@form.keys.each do |field|
					# If a key has multiple elements, apply filter to each element
					@field_array = Array( @form[field] )

					if @field_array.length > 1
						@field_array.each_index do |i|
							elem = @field_array[i]
							@field_array[i] = self.send("filter_#{filter}", elem)
						end
					else
						if not @form[field].to_s.empty?
							@form[field] = self.send("filter_#{filter}", @form[field].to_s)
						end
					end
				end
			end
		end
		@form
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
			value.untaint
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
			return [key.untaint]
		elsif bracketed
			return [main.untaint] + bracketed.slice(1...-1).split('][').collect {|k| k.untaint }
		else
			return [main.untaint]
		end
	end

end # class Arrow::FormValidator



