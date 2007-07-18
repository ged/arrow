#!/usr/bin/env ruby
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
		:default_action => 'fontlist',
		:templates => {
			:form		  => 'imgtext/form.tmpl',
			:fontlist	  => 'imgtext/fontlist.tmpl',
			:reload		  => 'imgtext/reload.tmpl',
			:reload_error => 'imgtext/reload-error.tmpl',
		},
		:vargs => {
			:__default__ => {
				:required		=> [],
				:optional		=> [:imgtext, :fontsize, :fontface],
				:constraints	=> {
					:imgtext	=> /^[\x20-\x7e-]+$/,
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

		@background= GD::Image.trueColorAlpha( bkgnd, GD::AlphaTransparent )
		@foreground = GD::Image.trueColorAlpha( fgnd, GD::AlphaOpaque )
		@fonts = load_fonts( @fontdir )

		self.log.debug "Loaded %d fonts" % @fonts.length
	end


	######
	public
	######

	attr_reader :fontdir, :background, :foreground, :fonts

	### The action to run when the specified action method doesn't exist. This
	### is used to make the URL a bit shorter -- the action name becomes the
	### font name in effect.
	def action_missing_action( txn, *args )

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
	end


	### Display a list of the available fonts.
	def fontlist_action( txn, *rest )
		templ = self.load_template( :fontlist )
		templ.txn = txn
		templ.app = self
		templ.fonts = @fonts

		return templ
	end


	### Reload the fonts and display what changed.
	def reload_action( txn, *args )
		self.log.debug "Doing reload of fonts for child %d" % [ Process.pid ]

		newfonts = tmpl = nil

		# Try to reload the fonts, replacing the currently-loaded ones and
		# showing the differences if it succeeds, and showing the error and
		# keeping the old ones if it fails.
		begin
			newfonts = load_fonts( @fontdir )
		rescue Exception => err
			self.log.error "Caught exception while attempting to reload fonts: %s\n\t%s" %
				[ err.message, err.backtrace.join("\n\t") ]
			tmpl = self.load_template( :reload_error )
			tmpl.exception = err
		else
			tmpl = self.load_template( :reload )
			tmpl.newfonts = newfonts.reject {|name,font| @fonts.key?(name)}
			tmpl.removedfonts = @fonts.reject {|name,font| newfonts.key?(name)}
			@fonts = newfonts
		end

		tmpl.txn = txn
		tmpl.applet = self

		return tmpl
	end


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
			next unless File.file?( file ) && File.readable?( file )
			face = nil

			count += 1
			begin
				face = FT2::Face.load( file ) or
					raise ".load returned nil"
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

		self.log.debug "Mapped %d of %d font files" %
			[ fonts.keys.nitems, count ]
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
		pointsize = DefaultFontSize if pointsize.nil? || pointsize.zero?
		pointsize = MaxPointSize if pointsize > MaxPointSize
		pointsize = MinPointSize if pointsize < MinPointSize
		self.log.debug "Set pointsize to %p" % pointsize

		# Calculate the size of the image based on the size of the rendered text
		raise "No such font '#{face}'" unless @fonts.key?( face )
		font = @fonts[ face ][:file]
		self.log.debug "Font file is %p" % font
		err, brect = GD::Image.stringFT( @foreground, font, pointsize, 0, 0, 0, text )
		raise "Failed to calculate bounding-box for #{font}: #{err}" if err
		self.log.debug "Bounding rect: %p" % [ brect ]

		# Calculate the image size from the bounding rectangle with a 5-pixel
		# border.
		width = brect[2] - brect[6] + 10
		height = brect[3] - brect[7] + 10
		self.log.debug "Width: %d, height: %d" % [ width, height ]

		# Make the image and colors
		img = GD::Image.newTrueColor( width, height )
		self.log.debug "Created image object: %p" % [ img ]

		# If the GD library has been patched to support alpha-channel PNGs, turn
		# that on.
		if img.respond_to? :saveAlpha
			self.log.debug "Using saveAlpha"
			img.saveAlpha = true
			img.alphaBlending = false

		# Otherwise just muddle through as best we can with immediate compositing
		else
			self.log.debug "Using alphaBlending"
			img.alphaBlending = true	
			img.transparent( @background )
		end

		# Fill the image with the background and draw the text and a border with
		# the foreground color.
		self.log.debug "Filling background"
		img.fill( 1, 1, @background )
		self.log.debug "Drawing string"
		img.stringFT( @foreground, font, pointsize, 0, 5 - brect[6], 5 - brect[7], text )
		self.log.debug "Filled and set string."

		return img
	end

end # class FancyImageText


