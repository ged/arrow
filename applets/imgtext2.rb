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

	# TrueType font to use
	DefaultFont = 'TektonPro-Regular'
	DefaultFont.untaint
	DefaultFontDir = "/Library/WebServer/Fonts"
	DefaultFontDir.untaint

	# Colors
	DefaultForegroundColor = "#006600"
	DefaultBackgroundColor = "#ffffed"

	# Applet signature
	Signature = {
		:name => "imagetext",
		:description => "Generates an image from one or more characters of text.",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'form',
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

		@background= GD::Image::trueColor( bkgnd )
		@foreground = GD::Image::trueColor( fgnd )
		@fonts = load_fonts( @fontdir )

		self.log.debug "Loaded %d fonts" % @fonts.length
	end


	######
	public
	######

	attr_reader :fontdir, :background, :foreground, :fonts

	action( 'form' ) {|txn,*rest|
		templ = self.loadTemplate( :form )
		templ.txn = txn
		templ.app = self
		templ.fonts = @fonts

		return templ
	}

	action( 'png' ) {|txn,*rest|
		img = make_image( txn, rest )
		self.log.debug "Made image."

		txn.content_type = 'image/png'
		return img.pngStr
	}

	action( 'jpeg' ) {|txn,*rest|
		img = make_image( txn, rest )

		txn.content_type = 'image/jpeg'
		return img.jpegStr( -1 )
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
	def make_image( txn, rest )
		# Read the configuration from either the query args or the REST-style
		# parameters, preferring the former.
		text = $1 if /([\x20-\x7f]+)/.match( rest[0] )
		text ||= txn.vargs[:imgtext]
		text ||= "No valid text specified."
		self.log.debug "Set text to %p" % text

		# Get the face name the same way
		face = $1 if /(\S+)/.match( rest[1] )
		face ||= txn.vargs[:fontface]
		face ||= @defaultfont
		self.log.debug "Set face to %p" % face

		# Get the pointsize the same way
		pointsize = Integer($1) if /(\d+)/.match( rest[2] )
		pointsize ||= Integer( txn.vargs[:fontsize] ) rescue nil
		pointsize = 18 if pointsize.nil? || pointsize.zero?
		self.log.debug "Set pointsize to %p" % pointsize

		# Calculate the size of the image based on the size of the rendered text
		raise "No such font '#{face}'" unless @fonts.key?( face )
		font = @fonts[ face ][:file]
		self.log.debug "Font file is %p" % font
		err, brect = GD::Image::stringFT( @foreground, font, pointsize, 0, 0, 0, text )
		raise "Failed to calculate bounding-box for #{font}: #{err}" if err
		self.log.debug "Bounding rect: %p" % brect

		# Calculate the image size from the bounding rectangle with a 5-pixel
		# border.
		width = brect[2] - brect[6] + 10
		height = brect[3] - brect[7] + 10

		# Make the image and colors
		img = GD::Image::newTrueColor( width, height )

		# Fill the image with the background and draw the text and a border with
		# the foreground color.
		img.fill( 1, 1, @background )
		img.stringFT( @foreground, font, pointsize, 0, 5 - brect[6], 5 - brect[7], text )
		img.rectangle( 0,0, width-1, height-1, @foreground )

		return img
	end

end # class FancyImageText


