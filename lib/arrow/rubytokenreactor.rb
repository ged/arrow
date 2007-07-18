#!/usr/bin/env ruby
# 
# This file contains the Arrow::RubyTokenizer class, a derivative of
# Arrow::Object. Instances of this class can be used to parse a Ruby program
# into an Array of tokens suitable for parsing.
# 
# == Subversion Id
#
#  $Id$
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

begin
	require 'ripper.so'
rescue LoadError => err
	$fakedRipper = err
	class Ripper < ::Object #:nodoc:
		def initialize( *args )
			raise $fakedRipper
		end
	end
else
	$fakedRipper = false
end


require 'arrow/mixins'

### Simple Ruby tokenizer; used to parse a Ruby program into an Array of
### tokens suitable for rendering in some other form.
class Arrow::RubyTokenReactor < Ripper
	include Arrow::Loggable

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$



	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Parse the specified +source+ and call the +callback+ when any of the
	### given +events+ are seen.
	def self::parse( source, *events, &callback )
		reactor = self.new( source )
		if callback.nil?
			tokens = Hash.new {|h,k| h[k] = []}
			reactor.onEvents( *events ) {|tok, *args|
				tokens[ tok ].push args
			}
			reactor.parse
			return tokens
		else
			reactor.onEvents( *events, &callback )
			reactor.parse
		end
	end


	### Returns <tt>true</tt> if the Ripper parser loaded okay. If this is
	### false, the token reactor will not be functional.
	def self::loaded?
		return ! $fakedRipper
	end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new RubyTokenReactor object that will parse the specified
	### +source+ (either a String or an object that responds to #gets) and
	### call registered callbacks for parsed tokens. The +fname+ and
	### +lineno+ are for building error messages. See Ripper.new for more
	### info.
	def initialize( source, fname="(string)", lineno=1 )
		@callbacks = Hash.new {|hsh, key|
			hsh[ key ] = []
		}
		super
	end


	######
	public
	######

	# The Hash of events => [ callbacks ]
	attr_reader :callbacks


	### Register a +callback+ for the given +events+. Events are either
	### strings or symbols that match the events generated by Ripper,
	### optionally without the 'on__' prefix.
	def onEvents( *events, &callback )
		events.each {|ev|
			evsym = self.eventSym( ev )
			self.log.debug "Registering for the %p event" % evsym
			@callbacks[ evsym ] << callback
		}
	end


	### Remove all callbacks for the specified +events+. Returns the
	### callbacks that were removed.
	def cancelEvents( *events )
		callbacks = []
		events.each {|ev|
			evsym = self.eventSym( ev )
			callbacks << @callbacks.delete( evsym )
		}

		return callbacks.flatten
	end


	### Remove the specified +callback+ from the specified +event+. If
	### +event+ is nil, the callback is removed from all events that it is
	### registered for.
	def cancelCallback( callback, event=nil )
		if event.nil?
			@callbacks.each {|evsym,callbacks|
				callbacks.delete( callback )
			}
		else
			evsym = self.eventSym( event )
			@callbacks[ evsym ].delete( callback )
		end
	end


	### Return a normalized version of the given event as a symbol. Prepends
	### 'on__' if it isn't already, and turns strings into symbols.
	def eventSym( event )
		return event if event.to_s == "all"
		event.to_s.sub( /^(?!on__)/, 'on__' ).intern
	end



	#########
	protected
	#########

	### Log a warning
	def warn( fmt, *args )
		self.log.warning( "Parser warn: " + fmt, *args )
	end


	### Log a warning
	def warning( fmt, *args )
		self.log.warning( "Parser warning: " + fmt, *args )
	end


	### Log a parse error
	def compile_error( fmt, *args )
		self.log.error( "Parser compile error: " + fmt, *args )
	end


	### Handle any calls to methods not explicitly handled
	def method_missing( sym, *args )
		#self.log.debug "Parser: %s( %p )" % [ sym, args ]
		if @callbacks.key?( sym )
			@callbacks[ sym ].each {|callback|
				callback.call( self, *args )
			}
		end
		if @callbacks.key?( :all )
			@callbacks[ :all ].each {|callback|
				callback.call( self, sym, *args )
			}
		end
	end
end # class Arrow::RubyTokenizer
