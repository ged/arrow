#!/usr/bin/env ruby
# 
# This file contains the ImageText class, a derivative of Arrow::Applet. It is
# an applet which generates an image from one or more characters of text.
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
require 'arrow/applet'

### It is an applet which generates an image from one or more characters of text.
class ImageText < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Applet signature
	Signature = {
		:name => "imagetext",
		:description => "Generates an image from one or more characters of text.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'form',
		:templates => {
			:form	=> 'imgtext.tmpl',
		},
		:vargs => {
		}
	}



	######
	public
	######

	# PNG-creation action
	def_action :png do |txn,*rest|
		text = $1 if /([\x20-\x7e]+)/.match( rest.first )
		text ||= "No text specified."

		img = make_image( text )

		txn.content_type = 'image/png'
		return img.pngStr
	end

	# JPEG-creation action
	def_action :jpeg do |txn,*rest|
		text = $1 if /([\x20-\x7e]+)/.match( rest.first )
		text ||= "No text specified."

		img = make_image( text )

		txn.content_type = 'image/jpeg'
		return img.jpegStr( -1 )
	end


	#########
	protected
	#########

	def make_image( text )
		# Fetch the font and calculate the image dimensions from the text.
		font = GD::Font.new( "Medium" )
		width = font.width * text.length + 10
		height = font.height + 10

		# Make the image and colors
		img = GD::Image.newTrueColor( width, height )
		background= GD::Image.trueColor( 255, 255, 240 )
		foreground = GD::Image.trueColor( 0, 0, 0 )

		# Fill the image with the background and draw the text and a border with
		# the foreground color.
		img.fill( 1, 1, background )
		img.string( font, 5, 5, text, foreground )
		img.rectangle( 0,0, width-1, height-1, foreground )

		return img
	end

end # class ImageText


