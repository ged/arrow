#!/usr/bin/ruby
# 
# This file contains the FancyImageText class, a derivative of Arrow::Applet. It
# is an applet which generates an image of a string of TrueType text.
# 
# == Rcsid
# 
# $Id: TEMPLATE.rb.tpl,v 1.1 2003/11/01 19:42:05 deveiant Exp $
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

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: TEMPLATE.rb.tpl,v 1.1 2003/11/01 19:42:05 deveiant Exp $

	# TrueType font to use
	DefaultFont = "/Library/Fonts/TektonPro-Regular.otf"
	FontDir = "/Library/Fonts"

	# Colors
	ForegroundColor = "#000000"
	BackgroundColor = "#ffffed"

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
				:optional	=> [:imgtext, :"font-size", :"font-face"],
				:filters	=> [:strip, :squeeze],
				:constraints => {
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

		@background= GD::Image::trueColor( BackgroundColor )
		@foreground = GD::Image::trueColor( ForegroundColor )
		@fonts = load_fonts( FontDir )

		self.log.debug "Loaded %d fonts" % @fonts.length
	end


	######
	public
	######

	action( 'form' ) {|txn,*rest|
		templ = self.loadTemplate( :form )
		templ.txn = txn
		templ.app = self
		templ.fonts = @fonts

		return templ
	}

	action( 'png' ) {|txn,*rest|
		img = make_image( txn, rest )

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

	### Load FT2::Face objects for each of the readable fonts in the given
	### +dir+ and return them as a Hash.
	def load_fonts( dir )
		count = 0
		fonts = {}

		Dir[ "#{dir}/*" ].each {|file|
			next unless /\.(ttf|otf)$/i.match( file )

			count += 1
			begin
				self.log.debug "Attempting to load #{file}"
				face = FT2::Face.load( file )
			rescue Exception => err
				self.log.debug "While loading #{file}: %s" % err.message
				next
			end

			$stderr.puts [face, face.name, face.num_glyphs ].join ', '
			fonts[ face.name ] = { :file => file, :face => face }
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

		face = $1 if /(\S+)/.match( rest[1] )
		face ||= txn.vargs[:fontface]
		face ||= "Verdana"

		pointsize = Integer($1) if /(\d+)/.match( rest[2] )
		pointsize ||= Integer( txn.vargs[:fontsize] ) rescue nil
		pointsize ||= 18

		# Calculate the size of the image based on the size of the rendered text
		raise "No such font '#{face}'" unless @fonts.key?( face )
		font = @fonts[ face ][:file]
		err, brect = GD::Image::stringFT( @foreground, font, pointsize, 0, 0, 0, text )
		raise "Failed to calculate bounding-box for #{font}: #{err}" if err

		# Fetch the font and calculate the image dimensions from the text.
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


