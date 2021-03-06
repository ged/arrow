#!/usr/bin/ruby

require 'arrow'
require 'arrow/exceptions'
require 'arrow/mixins'


# Arrow::AcceptParam -- a parser for Accept headers, allowing for
# weighted and wildcard comparisions.
#
# == Synopsis
#
#   require 'arrow/acceptparam'
#	ap = Arrow::AcceptParam.parse( "text/html;q=0.9;level=2" )
#
#	ap.type         #=> 'text'
#	ap.subtype      #=> 'html'
#	ap.qvalue       #=> 0.9
#	ap =~ 'text/*'  #=> true
#
# == Authors
# 
# This class was originally written as part of the ThingFish project.
#
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::AcceptParam
	include Comparable,
		Arrow::Loggable

	# The default quality value (weight) if none is specified
	Q_DEFAULT = 1.0
	
	# The maximum quality value
	Q_MAX = Q_DEFAULT


	### Parse the given +accept_param+ and return an AcceptParam object.
	def self::parse( accept_param )
		raise Arrow::RequestError, "Bad Accept param: no media-range" unless
			accept_param =~ %r{/}
		media_range, *stuff = accept_param.split( /\s*;\s*/ )
		type, subtype = media_range.downcase.split( '/', 2 )
		qval, opts = stuff.partition {|par| par =~ /^q\s*=/ }

		return new( type, subtype, qval.first, *opts )
	end


	### Create a new Arrow::AcceptParam with the given media +range+, quality value 
	### (+qval+), and extensions
	def initialize( type, subtype, qval=Q_DEFAULT, *extensions )
		type    = nil if type == '*'
		subtype = nil if subtype == '*'

		@type       = type
		@subtype    = subtype
		@qvalue     = normalize_qvalue( qval )
		@extensions = extensions.flatten
	end


	######
	public
	######

	# The 'type' part of the media range
	attr_reader :type

	# The 'subtype' part of the media range
	attr_reader :subtype

	# The weight of the param
	attr_reader :qvalue

	# An array of any accept-extensions specified with the parameter
	attr_reader :extensions


	### Match operator -- returns true if +other+ (an AcceptParan or something
	### that can to_s to a mime type) is a mime type which matches the receiving
	### AcceptParam.
	def =~( other )
		unless other.is_a?( Arrow::AcceptParam )
			other = self.class.parse( other.to_s ) rescue nil
			return false unless other
		end

		# */* returns true in either side of the comparison.
		# ASSUMPTION: There will never be a case when a type is wildcarded
		#             and the subtype is specific. (e.g., */xml)
		#             We gave up trying to read RFC 2045.
		return true if other.type.nil? || self.type.nil?

		# text/html =~ text/html
		# text/* =~ text/html
		# text/html =~ text/*
		if other.type == self.type
			return true if other.subtype.nil? || self.subtype.nil?
			return true if other.subtype == self.subtype
		end

		return false
	end


	### Return a human-readable version of the object
	def inspect
		return "#<%s:0x%07x '%s/%s' q=%0.3f %p>" % [
			self.class.name,
			self.object_id * 2,
			self.type || '*',
			self.subtype || '*',
			self.qvalue,
			self.extensions,
		]
	end


	### Return the parameter as a String suitable for inclusion in an Accept
	### HTTP header
	def to_s
		return [
			self.mediatype,
			self.qvaluestring,
			self.extension_strings
		].compact.join(';')
	end


	### The mediatype of the parameter, consisting of the type and subtype
	### separated by '/'.
	def mediatype
		return "%s/%s" % [ self.type || '*', self.subtype || '*' ]
	end
	alias_method :mimetype, :mediatype
	alias_method :content_type, :mediatype


	### The weighting or "qvalue" of the parameter in the form "q=<value>"
	def qvaluestring
		# 3 digit precision, trim excess zeros
		return sprintf( "q=%0.3f", self.qvalue ).gsub(/0{1,2}$/, '')
	end


	### Return a String containing any extensions for this parameter, joined
	### with ';'
	def extension_strings
		return nil if @extensions.empty?
		return @extensions.compact.join('; ')
	end


	### Comparable interface. Sort parameters by weight: Returns -1 if +other+
	### is less specific than the receiver, 0 if +other+ is as specific as
	### the receiver, and +1 if +other+ is more specific than the receiver.
	def <=>( other )

		if rval = (other.qvalue <=> @qvalue).nonzero?
			return rval
		end

		if @type.nil?
			return 1 if ! other.type.nil?
		elsif other.type.nil?
			return -1
		end

		if @subtype.nil?
			return 1 if ! other.subtype.nil?
		elsif other.subtype.nil?
			return -1
		end

		if rval = (other.extensions.length <=> @extensions.length).nonzero?
			return rval
		end

		return self.mediatype <=> other.mediatype
	end


	#######
	private
	#######

	### Given an input +qvalue+, return the Float equivalent.
	def normalize_qvalue( qvalue )
		return Q_DEFAULT unless qvalue
		qvalue = Float( qvalue.to_s.sub(/q=/, '') ) unless qvalue.is_a?( Float )

		if qvalue > Q_MAX
			self.log.notice "Squishing invalid qvalue %p to %0.1f" %
				[ qvalue, Q_DEFAULT ]
			return Q_DEFAULT
		end

		return qvalue
	end

end # Arrow::AcceptParam

# vim: set nosta noet ts=4 sw=4:
