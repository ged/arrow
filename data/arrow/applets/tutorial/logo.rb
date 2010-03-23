#!/usr/bin/env ruby
# 
# The LogoGenerator class, a derivative of Arrow::Applet. It
# generates a blank logo of a given size and format.
# 
# == VCS Id
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/applet'
require 'GD'

### It generates a blank logo of a given size and format.
class LogoGenerator < Arrow::Applet


	# Applet signature
	Signature = {
		:name => "Logo Generator",
		:description => "Generate a blank logo of a given size and format.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'display',
		:vargs => {
			:display => {
				:optional => [:height, :width, :format],
				:constraints => {
					:height		=> /^\d+$/,
					:width		=> /^\d+$/,
					:format		=> /^(png|jpe?g|gif)$/,
				},
			},
		}
	}


	def initialize( *args )
		super
		
		@defaultLogoWidth = 60
		@defaultLogoHeight = 60
		@defaultLogoImageFormat = :png

		@background= GD::Image.trueColorAlpha( "#ffffff", GD::AlphaTransparent )
		@foreground = GD::Image.trueColorAlpha( "#000000", GD::AlphaOpaque )
	end


	######
	public
	######

	def display_action( txn, *args )
		width = txn.vargs[ :width ] || @defaultLogoWidth
		height = txn.vargs[ :height ] || @defaultLogoHeight
		format = txn.vargs[ :format ] || @defaultLogoImageFormat
		self.log.debug "height = %d, width = %d, format = %p" %
			[ height, width, format ]

		img = GD::Image.newTrueColor( width, height )
		self.log.debug "Created image"

		if img.respond_to? :saveAlpha
			self.log.debug "Using saveAlpha"
			img.saveAlpha = true
			img.alphaBlending = false

			# Otherwise just muddle through as best we can with immediate compositing
		else
			self.log.debug "Using alphaBlending"
			img.alphaBlending = true	
			img.transparent( background )
		end

		img.fill( 1, 1, @background )
		self.log.debug "Filled it with %p" % @background
		img.rectangle( 0, 0, width - 1, height - 1, @foreground )
		self.log.debug "Drew bounding rectangle"
		img.line( 0, 0, width - 1, height - 1, @foreground )
		self.log.debug "Draw first crosshatch"
		img.line( 0, height - 1, width - 1, 0, @foreground )
		self.log.debug "Draw second crosshatch"

		imgdata = img.pngStr
		self.log.debug "Extracted image data (%d bytes)" % imgdata.length
		txn.request.content_type = "image/png"

		return imgdata
	end


end # class LogoGenerator


