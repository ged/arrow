#!/usr/bin/ruby
# 
# This file contains the FancyImageText class, a derivative of Arrow::Applet. It
# is an applet which generates an image of a string of TrueType text.
# 
# == Rcsid
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Thanks to Mahlon Smith <mahlon@martini.nu> for ideas for refinement,
# suggestions.
# 

require 'GD'
require 'ft2'
require 'arrow/applet'

### It is an applet which generates an image from one or more characters of text.
class FancyImageText < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Default settings
	DefaultFont = 'TektonPro-Regular'
	DefaultFont.untaint
	DefaultFontDir = "/Library/WebServer/Fonts"
	DefaultFontDir.untaint

	DefaultFontSize = 36
	DefaultText = 'TrueType Font Mangler'

	# Colors
	DefaultForegroundColor = "#000000"
	DefaultBackgroundColor = "#ffffff"

	# Safety constraints
	MaxPointSize = 180
	MinPointSize = 5
	MaxTextLength = 1024

	# URLs of the form: /ttf/<fontname>/<size>/<caption>.<fmt>
	# Stolen shamelessly from Mahlon.
	FileName = %r{(.*)\.(png|jpg)}i

	# Applet signature
	Signature = {
		:name => "imagetext",
		:description => "Generates an image from one or more characters of text.",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'fontlist',
		:templates => {
			:form		=> 'imgtext.tmpl',
			:fontlist	=> 'imgtext-fontlist.tmpl',
		},
		:vargs => {
			:__default__ => {
				:required		=> [],
				:optional		=> [:imgtext, :fontsize, :fontface],
				:constraints	=> {
					:imgtext	=> /^[\x20-\x7e]+$/,
					:fontsize	=> /^\d+$/,
					:fontface	=> /^\S+$/,
				},
			},
		}
	}


	### Load some stuff when the applet is created.
 	def initialize( *args ) # :nodoc:
		super

		if @config.respond_to?( :imgtext )
			bkgnd = @config.imgtext.background
			fgnd = @config.imgtext.foreground
			@fontdir = @config.imgtext.fontdir
			@defaultfont = @config.imgtext.defaultfont
		end

		bkgnd ||= DefaultBackgroundColor
		fgnd ||= DefaultForegroundColor
		@fontdir ||= DefaultFontDir
		@defaultfont ||= DefaultFont

		@background= GD::Image::trueColorAlpha( bkgnd, GD::AlphaTransparent )
		@foreground = GD::Image::trueColorAlpha( fgnd, GD::AlphaOpaque )
		@fonts = load_fonts( @fontdir )

		self.log.debug "Loaded %d fonts" % @fonts.length
	end


	######
	public
	######

	attr_reader :fontdir, :background, :foreground, :fonts


	action( 'action_missing' ) {|txn, *args|

		# Fetch the REST arguments and build the image for them
		fontname, size, imgname = *args
		caption, fmt = $1, $2 if FileName.match( imgname )
		img = make_image( txn, fontname, size, caption ) or return false

		self.log.debug "Made %s image with font: %s, size: %d, caption: %p" %
			[ fmt, fontname, size, caption ]
		
		# Render the image according to what extension the URI had
		case fmt
		when /png/
			txn.content_type = 'image/png'
			return img.pngStr
			
		when /jpg/
			txn.content_type = 'image/jpeg'
			return img.jpegStr( -1 )
			
		else
			self.log.error "Unsupported image extension %p" % fmt
			return false
		end
	}

	action( 'fontlist' ) {|txn, *rest|
		templ = self.loadTemplate( :fontlist )
		templ.txn = txn
		templ.app = self
		templ.fonts = @fonts

		return templ
	}



	#########
	protected
	#########

	### Load Hashes full of font info for each of the readable fonts in the
	### given +dir+ and return them in a Hash keyed by the font name.
	def load_fonts( dir )
		count = 0
		fonts = {}

		Dir["#{dir}/*.{otf,ttf}"].each {|file|
			file.untaint
			next unless File::file?( file ) && File::readable?( file )
			face = nil

			count += 1
			begin
				self.log.debug "Attempting to load #{file}"
				face = FT2::Face::load( file ) or
					raise "::load returned nil"
			rescue Exception => err
				self.log.debug "While loading #{file}: %s" % err.message
				next
			end

			fonts[ face.name ] = {
				:file => file,
				:family => face.family,
				:style => face.style,
				:bold => face.bold?,
				:italic => face.italic?,
			}
		}

		return fonts
	end


	### Create a GD::Image object from the given +txn+ and +rest+-style
	### arguments.
	def make_image( txn, fontname, size, caption )

		# Arguments are read from either the query args or the REST-style
		# parameters, preferring the latter.

		# Fetch the text and normalize it
		text = $1 if /([\x20-\x7f]+)/.match( caption )
		text ||= txn.vargs[:imgtext]
		text ||= DefaultText
		text = text[0, MaxTextLength] if text.length > MaxTextLength
		self.log.debug "Set text to %p" % text

		# Get the face name the same way
		face = $1 if /(\S+)/.match( fontname )
		face ||= txn.vargs[:fontface]
		face ||= @defaultfont
		self.log.debug "Set face to %p" % face

		# Get the pointsize the same way
		pointsize = Integer($1) if /(\d+)/.match( size )
		pointsize ||= Integer( txn.vargs[:fontsize] ) rescue nil
		pointsize = DefaultPointSize if pointsize.nil? || pointsize.zero?
		pointsize = MaxPointSize if pointsize > MaxPointSize
		pointsize = MinPointSize if pointsize < MinPointSize
		self.log.debug "Set pointsize to %p" % pointsize

		# Calculate the size of the image based on the size of the rendered text
		raise "No such font '#{face}'" unless @fonts.key?( face )
		font = @fonts[ face ][:file]
		self.log.debug "Font file is %p" % font
		err, brect = GD::Image::stringFT( @foreground, font, pointsize, 0, 0, 0, text )
		raise "Failed to calculate bounding-box for #{font}: #{err}" if err
		self.log.debug "Bounding rect: %p" % [ brect ]

		# Calculate the image size from the bounding rectangle with a 5-pixel
		# border.
		width = brect[2] - brect[6] + 10
		height = brect[3] - brect[7] + 10
		self.log.debug "Width: %d, height: %d" % [ width, height ]

		# Make the image and colors
		img = GD::Image::newTrueColor( width, height )
		self.log.debug "Created image object: %p" % [ img ]

		# Fill the image with the background and draw the text and a border with
		# the foreground color.
		img.saveAlpha = true
		img.alphaBlending = false
		img.fill( 1, 1, @background )
		img.stringFT( @foreground, font, pointsize, 0, 5 - brect[6], 5 - brect[7], text )
		#img.transparent( @background )
		
		self.log.debug "Filled and set string."

		return img
	end

end # class FancyImageText


