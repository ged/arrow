#!/usr/bin/ruby
# 
# This file contains the Arrow::Template::Parser class, a derivative of
# Arrow::Object. This is the default parser class for the default Arrow
# templating system.
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

require 'strscan'
require 'forwardable'
require 'pluginfactory'

require 'arrow/object'
require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/template'
require 'arrow/utils'

### Default parser object class -- parses template source into template
### objects.
class Arrow::Template::Parser < Arrow::Object

	### Regexp constants for parsing
	module Patterns

		# The Regexp that is used to match directive tag openings. Must be at
		# least 2 characters wide.
		TAGOPEN = %r{([<|\[])\?}

		# The Hash that maps tag-closings to tag-middle patterns.
		TAGMIDDLE = Hash.new {|hsh, key|
			# Extract the first and second characters from the tag-closing
			# pattern to build the tag-middle pattern.
			src = key.is_a?( Regexp ) ? key.source : key.to_s
			mobj = /(\\.|.)(\\.|.)/.match( src ) or
				raise Arrow::ParseError, "couldn't extract first and second "\
				"char from closing tag '%s'" % key
			char1, char2 = mobj[1,2]
			hsh[key] = Regexp.new( /((?:[^#{char1}]|#{char1}(?!#{char2}))+)/ )
		}

		# The Hash that maps tag openings to matching tag closings with flipped
		# braces.
		TAGCLOSE = Hash.new {|hsh, key| 
			compliment = key.reverse.tr('<{([', '>})]')
			hsh[key] = Regexp.new( Regexp.quote(compliment) )
		}

		# Paren-group map
		CAPTURE			= Hash.new {|hsh, key|
			Regexp.new( '(' + key.to_s + ')' )
		}
		ALTERNATION		= Hash.new {|hsh, *keys|
			Regexp.new( '(?:' + keys.join('|') + ')' )
		}


		# Constant patterns for parsing
		DOT				= /\./
		COMMA			= /,/
		WHITESPACE		= /\s*/
		EQUALS			= /=/

		INFIX			= /\.|::|(?>\[)/
		IDENTIFIER		= /[a-z]\w*/i
		LBRACKET		= /[\[(]/
		RBRACKET		= Hash.new {|hsh, key|
			compliment = key.tr( '<{([', '>})]' )
			hsh[key] = Regexp.new( Regexp.quote(compliment) )
		}

		NUMBER			= /[-+]?\d+(?:\.\d+)?(?:e-?\d+)?/

		# :FIXME: I would do this with something like
		# /(["'/])((?:[^\1]|\\\.)*)\1/, but Ruby apparently doesn't grok
		# backreferences inside character classes:
		# (ruby 1.8.1 (2003-10-25) [i686-linux])
		# irb(main):001:0> /(["'])((?:[^\1]|\\\.)*)\1/.match( \
		#    %{foo "and \"bar\" and baz" and some "other stuff"} )[0]
		#   ==> "\"and \"bar\" and baz\" and some \"other stuff\""
		TICKQSTRING		= /'((?:[^']|\\')*)'/
		DBLQSTRING		= /"((?:[^"]|\\")*)"/
		SLASHQSTRING	= %r{/((?:[^/]|\\/)*)/}
		QUOTEDSTRING	= ALTERNATION[[ TICKQSTRING, DBLQSTRING, SLASHQSTRING ]]

		SYMBOL			= /:[@$]?[a-z]\w+/ | /:/ +
			ALTERNATION[[ DBLQSTRING, TICKQSTRING ]]
		VARIABLE		= /(?:\$|@@?)?_?/ + IDENTIFIER

		REGEXP			= %r{/((?:[^/]|\\.)+)/}
		REBINDOP		= /\s*(?:=~|matches)(?=\s)/

		PATHNAME		= %r{((?:[-\w.,:+@#$\%\(\)/]|\\ |\?(?!>))+)}

		ARGUMENT		= /[*&]?/ + IDENTIFIER
		ARGDEFAULT		= EQUALS + WHITESPACE +
			ALTERNATION[[ IDENTIFIER, NUMBER, QUOTEDSTRING, SYMBOL, VARIABLE ]]

	end
	include Patterns


	### Parse state object class. Instance of this class represent a
	### parser's progress through a given template body.
	class State < Arrow::Object
		include Patterns
		extend Forwardable

		### Create and return a new parse state for the specified
		### +text+. The +initialData+ is used to propagate directive
		### bookkeeping state through recursive parses.
		def initialize( text, template, initialData={} )
			@scanner = StringScanner.new( text )
			@template = template
			@tag_open = nil
			@tag_middle = nil
			@tag_close = nil
			@current_branch = []
			@current_branch_node = nil
			@current_node = nil
			@data = initialData

			#self.log.debug "From %s: Created a parse state for %p (%p). Data is: %p" %
			#	[ caller(1).first, text, template, initialData ]
		end


		######
		public
		######

		# Delegate the index operators to the @data hash
		def_delegators :@data, :[], :[]=

		# The template that corresponds to the parse state
		attr_reader :template

		# The StringScanner object which is scanning the text being parsed.
		attr_reader :scanner

		# The current branch of the parse state. Branches are added and
		# removed for re-entrances into the parse loop.
		attr_reader :current_branch

		# The pointer into the syntax tree for the node which is the base of
		# the current branch.
		attr_reader :current_branch_node

		# The pointer into the syntax tree for the current node
		attr_reader :current_node

		# The string that contains the opening string of the current tag, if
		# any.
		attr_reader :tag_open

		# The pattern that will match the middle of the current tag during
		# the parse of a directive.
		attr_accessor :tag_middle

		# The pattern that will match the current tag-closing characters during
		# the parse of a directive.
		attr_accessor :tag_close

		# A miscellaneous data hash to allow directives to keep their own
		# state for a parse.
		attr_reader :data


		### Return the line number of the line on which the parse's pointer
		### current rests.
		def line
			return @scanner.string[ 0, @scanner.pos ].count( $/ ) + 1
		end


		### Set the middle and closing tag patterns from the given matched
		### opening string.
		def set_tag_patterns( opening )
			@tag_open = opening
			@tag_close = TAGCLOSE[ opening ]
			@tag_middle = TAGMIDDLE[ @tag_close ]
		end


		### Add the given +nodes+ to the state's syntax tree.
		def add_nodes( *nodes )
			@current_branch.push( *nodes )
			@current_node = @current_branch.last
			return self
		end
		alias_method :<<, :add_nodes


		### Add a branch belonging to the specified +node+ to the parse
		### state for the duration of the supplied block, removing and
		### returning it when the block returns.
		def branch( node )
			raise LocalJumpError, "no block given" unless
				block_given?

			# Save and set the current branch node
			entryNode = @current_branch_node
			@current_branch_node = node

			# Push a new branch and make the current branch point to it
			# while saving the one we entered with so it can be restored
			# later.
			entryBranch = @current_branch
			entryBranch.push( @current_branch = [] )

			yield( self )

			# Restore the current branch and branch node to what they were
			# before
			@current_branch = entryBranch
			@current_branch_node = entryNode

			return @current_branch.pop
		end
	end # class State


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Default configuration hash
	Defaults = {
		:strict_end_tags			=> false,
		:ignore_unknown_PIs		=> true,
	}


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new parser using the specified +config+. The +config+ can
	### contain one or more of the following keys:
	###
	### [<b>:strict_end_tags</b>]
	###   Raise an error if the optional name associated with an <?end?> tag
	###   doesn't match the directive it closes. Defaults to +false+.
	### [<b>:ignore_unknown_PIs</b>]
	###   When this is set to +true+, any processing instructions found in a
	###   template that don't parse will be kept as-is in the output. If
	###   this is +false+, unrecognized PIs will raise an error at parse
	###   time. Defaults to +true+.
	def initialize( config={} )
		@config = Defaults.merge( config, &Arrow::HashMergeFunction )
	end


	### Initialize a duplicate of the +original+ parser.
	def initialize_copy( original )
		super
		@config = original.config.dup
	end


	######
	public
	######

	# The configuration object which contains the parser's config.
	attr_reader :config


	### Parse and return a template syntax tree from the given +string+.
	def parse( string, template, initialData={} )

		# Create a new parse state and build the parse tree with it.
		begin
			state = State.new( string, template, initialData )
			syntax_tree = self.scan_for_nodes( state )
		
		rescue Arrow::TemplateError => err
			Kernel.raise( err ) unless defined? state
			state.scanner.unscan if state.scanner.matched? #<- segfaults
			
			# Get the linecount and chunk of erroring content
			errorContent = get_parse_context( state.scanner )
			
			msg = err.message.split( /:/ ).uniq.join( ':' ) +
				%{ at line %d of %s: %s...} %
				[ state.line, template._file, errorContent ]
			Kernel.raise( err.class, msg )
		end

		return syntax_tree
	end


	### Use the specified +state+ (a StringScanner object) to scan for
	### directive and plain-text nodes.  The +context+ argument, if set,
	### indicates a recursive call for the directive named. The +node+ will
	### be used as the branch node in the parse state.
	def scan_for_nodes( state, context=nil, node=nil )
		return state.branch( node ) do
			scanner = state.scanner

			# Scan until the scanner reaches the end of its string. Early exits
			# 'break' of this loop.
			catch( :endscan ) {
				until scanner.eos?
					startpos = scanner.pos
					#self.log.debug %{Scanning from %d:%p} %
					#	[ scanner.pos, scanner.rest[0,20] + '..' ]
				
					# Scan for the next directive. When the scanner reaches
					# the end of the parsed string, just append any plain
					# text that's left and stop scanning.
					if scanner.skip_until( TAGOPEN )

						# Add the literal String node leading up to the tag
						# as a text node :FIXME: Have to do it this way
						# because StringScanner#pre_match does weird crap if
						# skip_until skips only one or no character/s.
						if ( scanner.pos - startpos > scanner.matched.length )
							offset = scanner.pos - scanner.matched.length - 1
							state << Arrow::Template::TextNode.
								new( scanner.string[startpos..offset] )
							#self.log.debug "Added text node %p" %
							#	scanner.string[startpos..offset]
						end

						# Now scan the directive that was found
						state << self.scan_directive( state, context )
					else
						state << Arrow::Template::TextNode.new( scanner.rest )
						scanner.terminate
					end
				end
			}
		end
	end


	### Given the specified parse +state+ which is pointing past the opening
	### of a directive tag, parse the directive.
	def scan_directive( state, context=nil )
		scanner = state.scanner

		# Set the patterns in the parse state to compliment the
		# opening tag.
		state.set_tag_patterns( scanner.matched )
		tag_begin = state.line

		# Scan for the directive name; if no valid name can be
		# found, handle an unknown PI/directive.
		scanner.skip( WHITESPACE )
		unless (( tag = scanner.scan( IDENTIFIER ) ))
			#self.log.debug "No identifier at '%s...'" % scanner.rest[0,20]

			# If the tag_open is <?, then this is a PI that we don't
			# grok. The reaction to this is configurable, so decide what to
			# do.
			if state.tag_open == '<?'
				return handle_unknown_pi( state )

			# ...otherwise, it's just a malformed non-PI tag, which
			# is always an error.
			else
				raise Arrow::ParseError, "malformed directive name"
			end
		end

		# If it's anything but an 'end' tag, create a directive object.
		unless tag == 'end'
			begin
				node = Arrow::Template::Directive.create( tag, self, state )
			rescue ::FactoryError => err
				return self.handle_unknown_pi( state, tag )
			end

		# If it's an 'end', 
		else
			#self.log.debug "Found end tag."

			# If this scan is occuring in a recursive parse, make sure the
			# 'end' is closing the correct thing and break out of the node
			# search. Note that the trailing '?>' is left in the scanner to
			# match at the end of the loop that opened this recursion.
			if context
				scanner.skip( WHITESPACE )
				closed_tag = scanner.scan( IDENTIFIER )
				#self.log.debug "End found for #{closed_tag}"

				# If strict end tags is turned on, check to be sure we
				# got the correct 'end'.
				if @config[:strict_end_tags]
					raise Arrow::ParseError,
						"missing or malformed closing tag name" if
						closed_tag.nil?
					raise Arrow::ParseError,
						"mismatched closing tag name '#{closed_tag}'" unless
						closed_tag.downcase == context.downcase
				end

				# Jump out of the loop in #scan_for_nodes...
				throw :endscan 
			else
				raise Arrow::ParseError, "dangling end"
			end
		end

		# Skip to the end of the tag
		self.scan_for_tag_ending( state ) or
			raise Arrow::ParseError,
				"malformed tag starting at line %d: no closing tag "\
				"delimiters %p found" % [ tag_begin, state.tag_close ]

		return node
	end


	### Given the specified +state+ (an Arrow::Template::Parser::State
	### object), scan for and return an indentifier. If +skip_whitespace+ is
	### +true+, any leading whitespace characters will be skipped. Returns
	### +nil+ if no identifier is found.
	def scan_for_identifier( state, skip_whitespace=true )
		#self.log.debug "Scanning for identifier at %p" %
		#	state.scanner.rest[0,20]

		state.scanner.skip( WHITESPACE ) if skip_whitespace
		rval = state.scanner.scan( IDENTIFIER ) or return nil

		#self.log.debug "Found identifier %p" % rval
		return rval
	end


	### Given the specified +state+ (an Arrow::Template::Parser::State
	### object), scan for and return a quoted string, including the
	### quotes. If +skip_whitespace+ is +true+, any leading whitespace
	### characters will be skipped. Returns +nil+ if no quoted string is
	### found.
	def scan_for_quoted_string( state, skip_whitespace=true )
		#self.log.debug "Scanning for quoted string at %p" %
		#	state.scanner.rest[0,20]

		state.scanner.skip( WHITESPACE ) if skip_whitespace

		rval = state.scanner.scan( QUOTEDSTRING ) or return nil

		#self.log.debug "Found quoted string %p" % rval
		return rval
	end


	### Given the specified +state+ (an Arrow::Template::Parser::State
	### object), scan for and return a methodchain. Returns +nil+ if no
	### methodchain is found.
	def scan_for_methodchain( state )
		scanner = state.scanner
		#self.log.debug "Scanning for methodchain at %p" %
		#	scanner.rest[0,20]

		rval = scanner.scan( INFIX ) || ''
		rval << (scanner.scan( WHITESPACE ) || '')
		rval << (scanner.scan( state.tag_middle ) || '')

		#self.log.debug "Found methodchain %p" % rval
		return rval
	end


	### Given the specified +state+ (an Arrow::Template::Parser::State
	### object), scan for and return the current tag ending. Returns +nil+
	### if no tag ending is found.
	def scan_for_tag_ending( state, skip_whitespace=true )
		scanner = state.scanner
		#self.log.debug "Scanning for tag ending at %p" %
		#	scanner.rest[0,20]

		scanner.skip( WHITESPACE ) if skip_whitespace
		rval = scanner.scan( state.tag_close ) or
			return nil

		#self.log.debug "Found tag ending %p" % rval
		return rval
	end


	### Given the specified +state+ (an Arrow::Template::Parser::State
	### object), scan for and return two Arrays of identifiers. The first is
	### the list of parsed arguments as they appeared in the source, and the
	### second is the same list with all non-word characters removed. Given
	### an arglist like:
	###   foo, bar=baz, *bim, &boozle
	### the returned arrays will contain: 
	###   ["foo", "bar=baz", "*bim", "&boozle"]
	### and
	###   ["foo", "bar", "bim", "boozle"]
	### respectively.
	def scan_for_arglist( state, skip_whitespace=true )
		scanner = state.scanner
		#self.log.debug "Scanning for arglist at %p" %
		#	scanner.rest[0,20]

		args = []
		pureargs = []
		scanner.skip( WHITESPACE ) if skip_whitespace
		while (( rval = scanner.scan(ARGUMENT) ))
			args << rval
			pureargs << rval.gsub( /\W+/, '' )
			scanner.skip( WHITESPACE )
			if (( rval = scanner.scan(ARGDEFAULT) ))
				args.last << rval
			end
			break unless scanner.skip( WHITESPACE + COMMA + WHITESPACE )
		end

		return nil if args.empty?

		#self.log.debug "Found args: %p, pureargs: %p" %
		#	[ args, pureargs ]
		return args, pureargs
	end


	### Given the specified +state+ (an Arrow::Template::Parser::State
	### object), scan for and return a valid-looking file pathname.
	def scan_for_pathname( state, skip_whitespace=true )
		scanner = state.scanner
		#self.log.debug "Scanning for file path at %p" %
		#	scanner.rest[0,20]

		scanner.skip( WHITESPACE ) if skip_whitespace
		rval = scanner.scan( PATHNAME ) or
			return nil

		#self.log.debug "Found path: %p" % rval
		return rval
	end



	#########
	protected
	#########

	### Handle an unknown ProcessingInstruction.
	def handle_unknown_pi( state, tag="" )
		
		# If the configuration doesn't say to ignore unknown PIs or it's an
		# [?alternate-synax?] directive, raise an error.
		if state.tag_open == '[?' || !@config[:ignore_unknown_PIs]
			raise Arrow::ParseError, "unknown directive"
		end

		remainder = state.scanner.scan( %r{(?:[^?]|\?(?!>))*\?>} ) or
			raise Arrow::ParseError, "failed to skip unknown PI"

		pi = state.tag_open + tag + remainder
		self.log.info( "Ignoring unknown PI (to = #{state.tag_open.inspect}) '#{pi}'" )
		return Arrow::Template::TextNode.new( pi )
	end


	### Return a string showing the given +scanner+'s context in the string
	### being parsed.
	def get_parse_context( scanner )
		str = scanner.string
		
		pre = str[ scanner.pos < 40 ? 0 : scanner.pos - 40, 39 ]
		post = scanner.rest[ 0, 40 ]
		
		return "#{pre}[*** ERROR ***]#{post}"
	end

end # class Arrow::Template::Parser
