#!/usr/bin/ruby
# 
# This file contains the Arrow::HTMLTokenizer class and a collection of token
# classes. HTMLTokenizer is a simple HTML parser that can be used to break HTML
# down into tokens.
#
# Some of the code and design were stolen from the excellent HTMLTokenizer
# library by Ben Giddings <bg@infofiend.com>.
# 
# == Rcsid
# 
# $Id: htmltokenizer.rb,v 1.2 2003/12/10 18:46:39 deveiant Exp $
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
require 'arrow/object'
require 'arrow/mixins'


module Arrow

	### A simple HTML tokenizer object class that can be used to break HTML down
	### into tokens.
	class HTMLTokenizer < Arrow::Object
		include Enumerable

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.2 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: htmltokenizer.rb,v 1.2 2003/12/10 18:46:39 deveiant Exp $


		### Create a new Arrow::HtmlTokenizer object.
		def initialize( source )
			@source = source
			@scanner = StringScanner::new( source )
		end


		######
		public
		######

		# The HTML source being tokenized
		attr_reader :source

		# The StringScanner doing the tokenizing
		attr_reader :scanner


		### Enumerable interface: Iterates over parsed tokens, calling the
		### supplied block with each one.
		def each
			@scanner.reset

			until @scanner.empty?
				if @scanner.peek(1) == '<'
					tag = @scanner.scan_until( />/ )

					case tag
					when /^<!--/
						token = HTMLComment::new( tag )
					when /^<!/
						token = DocType::new( tag )
					when /^<\?/
						token = ProcessingInstruction::new( tag )
					else
						token = HTMLTag::new( tag )
					end
				else
					text = @scanner.scan( /[^<]+/ )
					token = HTMLText::new( text )
				end

				yield( token )
			end
		end



		#########
		protected
		#########


	end # class HTMLTokenizer


	### Base class for HTML tokens output by Arrow::HTMLTokenizer.
	class HTMLToken < Arrow::Object

		### Initialize a token with the +raw+ source of it.
		def initialize( raw ) # :notnew:
			super()
			@raw = raw
		end

		# The raw source of the token
		attr_accessor :raw
		alias_method :to_s, :raw

		### Return an HTML fragment that can be used to represent the token
		### symbolically in a web-based introspection interface.
		def to_html
			content = nil

			if block_given? 
				content = yield
				# self.log.debug "content = %p" % content
			else
				content = self.escapeHTML( @raw )
			end

			tokenclass = self.cssClass

			%q{<span class="token %s">%s</span>} % [
				tokenclass,
				content,
			]
		end


		### Return the HTML element class attribute that corresponds to this node.
		def cssClass
			tokenclass = self.class.name.
				sub( /Arrow::(HTML)?/i, '').
				gsub( /::/, '-' ).
				gsub( /([a-z])([A-Z])/, "\\1-\\2" ).
				gsub( /[^-\w]+/, '' ).
				downcase
			tokenclass << "-token" unless /-token$/.match( tokenclass )

			return tokenclass
		end


		### Escape special characters in the given +string+ for display in an
		### HTML inspection interface. This escapes common invisible characters
		### like tabs and carriage-returns in additional to the regular HTML
		### escapes.
		def escapeHTML( string )
			return "nil" if string.nil?
			string = string.inspect unless string.is_a?( String )
			string.
				gsub(/&/, '&amp;').
				gsub(/</, '&lt;').
				gsub(/>/, '&gt;').
				gsub(/\r?\n/, %Q{<br />\n}).
				gsub(/\t/, '&nbsp;&nbsp;&nbsp;&nbsp;')
		end
	end


	### Class for tokens output by Arrow::HTMLTokenizer for the text bits of an
	### HTML document.
	class HTMLText < HTMLToken
		
		### Return an HTML fragment that can be used to represent the token
		### symbolically in a web-based introspection interface.
		def to_html
			marked = self.escapeHTML( @raw )
			marked.gsub( /(&amp;[^;]+;)/ ) {|ent|
				%Q{<span class="entity">#{ent}</span>}
			}
			super { marked  }
		end

	end


	### Class for tokens output by Arrow::HTMLTokenizer for HTML comments.
	class HTMLComment < HTMLToken
		CommentPattern =  /^<!--((?:[^-]|-(?!-))*)-->$/

		def initialize( raw )
			super

			unless (( match = CommentPattern.match(raw) ))
				raise ArgumentError,
					"Malformed comment %p" % raw
			end

			@contents = match[1]
		end

		attr_accessor :contents
	end


	### Class for tokens output by Arrow::HTMLTokenizer for the tags in an HTML
	### document.
	class HTMLTag < HTMLToken

		# The pattern for matching tag attribute key-value pairs
		AttributePattern = %r{
			\s*([-A-Za-z:]+)
			(?:\s*=\s*(
				"(?:[^"]|\\.)*" |		# Match strings quoted with "
				'(?:[^']|\\.)*' |		# Match strings quoted with '
				\S+						# Match non-whitespace
			))?
		}mx

		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new HTMLTag from the specified raw source.
		def initialize( raw )
			unless (( match = /<\s*(\/)?(\w+)\s*([^>]*)>/.match(raw) ))
				raise ArgumentError,
					"Malformed HTMLTag: %p" % raw
			end

			@endtag = !match[1].nil?
			@tagname = match[2]
			@rawattrs = match[3] || ''
			@attrs = nil

			super
		end


		######
		public
		######

		# The name of the tag
		attr_reader :tagname

		### Returns +true+ if this tag is an closing tag
		def endtag?; @endtag; end


		### Return the Hash of tag attributes belonging to this token.
		def attrs
			unless @attrs
				@attrs = {}
				@rawattrs.scan( AttributePattern ) {|name,value|
					ns = nil
					if /:/ =~ name
						ns, name = name.split(/:/, 2)
						if ns == 'html' then ns = nil end
					end
					cname = name.gsub(/-/, '_').downcase
					cval = value.nil? ? true : value.gsub(/^["']|['"]$/, '')

					if ns.nil?
						@attrs[ cname.intern ] = cval
					else
						@attrs[ ns.intern ] ||= {}
						@attrs[ ns.intern ][ name.intern ] = cval
					end
				}
			end

			return @attrs
		end


		### Return the tag attribute with the specified name (if it exists).
		def []( name )
			self.attrs[ name.gsub(/-/, '_').downcase.intern ]
		end

		
		### Return an HTML fragment that can be used to represent the token
		### symbolically in a web-based introspection interface.
		def to_html
			tagopen, tagbody = @raw.split( /\s+/, 2 )
			# self.log.debug "tagopen = %p, tagbody = %p" % [ tagopen, tagbody ]

			tagopen = self.escapeHTML( tagopen ).sub( %r{^&lt;(/)?(\w+)} ) {|match|
				%Q{&lt;#$1<span class="tag-token-name">#$2</span>}
			}

			unless tagbody.nil?
				tagbody.sub!( />$/, '' )
				tagbody = self.escapeHTML( tagbody ).gsub( AttributePattern ) {|match|
					name, mid, val = match.split(/(\s*=\s*)/, 2)

					val.gsub!( /(\[\?(?:[^\?]|\?(?!\]))+\?\])/s ) {|m|
						%q{<span class="%s">%s</span>} %
							[ 'tag-attr-directive', m ]
					}

					%q{<span class="%s">%s</span>%s<span class="%s">%s</span>} % [
						'tag-token-attr-name',
						name,
						mid,
						'tag-token-attr-value',
						val,
					]
				}
				tagbody << '&gt;'
			end

			#self.log.debug "tagopen = %p; tagbody = %p" %
			#	[ tagopen, tagbody ]
			super { [tagopen, tagbody].compact.join(" ") }
		end

		### Escape special characters in the given +string+ for display in an
		### HTML inspection interface.
		def escapeHTML( string )
			return "nil" if string.nil?
			string = string.inspect unless string.is_a?( String )
			string.
				gsub(/&/, '&amp;').
				gsub(/</, '&lt;').
				gsub(/>/, '&gt;')
		end
	end


	### Class for tokens output by Arrow::HTMLTokenizer for the processing
	### instructions contained in an HTML document.
	class ProcessingInstruction < HTMLToken
		def initialize( raw )
			@instruction, @body = raw.gsub(/^\?|\?$/, '').split( /\s+/, 2 )
			super
		end

		attr_accessor :instruction, :body
	end


	### Class for tokens output by Arrow::HTMLTokenizer for the doctype
	### declaration of an HTML document.
	class DocType < HTMLToken
	end


end # module Arrow


