#!/usr/bin/ruby
#
# Minimal testcase to track down a GD bug
# 
# Time-stamp: <03-Aug-2005 21:56:35 ged>
#

BEGIN {
	base = File.dirname( File.dirname(File.expand_path(__FILE__)) )
	$LOAD_PATH.unshift "#{base}/lib"

	require "#{base}/utils.rb"
	include UtilityFunctions
}

require 'GD'
require 'ft2'

def debugMsg( fmt, *args )
	$deferr.puts( fmt % args )
end


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
			debugMsg "While loading #{file}: %s" % err.message
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

	debugMsg "Mapped %d of %d font files" %
		[ fonts.keys.nitems, count ]
	return fonts
end


### Create a GD::Image object from the given +txn+ and +rest+-style
### arguments.
def make_image( face, pointsize, text )

	# Calculate the size of the image based on the size of the rendered text
	raise "No such font '#{face}'" unless Fonts.key?( face )
	font = Fonts[ face ][:file]
	debugMsg "Font file is %p" % font
	err, brect = GD::Image.stringFT( Foreground, font, pointsize, 0, 0, 0, text )
	raise "Failed to calculate bounding-box for #{font}: #{err}" if err
	debugMsg "Bounding rect: %p" % [ brect ]

	# Calculate the image size from the bounding rectangle with a 5-pixel
	# border.
	width = brect[2] - brect[6] + 10
	height = brect[3] - brect[7] + 10
	debugMsg "Width: %d, height: %d" % [ width, height ]

	# Make the image and colors
	img = GD::Image.newTrueColor( width, height )
	debugMsg "Created image object: %p" % [ img ]

	# If the GD library has been patched to support alpha-channel PNGs, turn
	# that on.
	if img.respond_to? :saveAlpha
		debugMsg "Using saveAlpha"
		img.saveAlpha = true
		img.alphaBlending = false

		# Otherwise just muddle through as best we can with immediate compositing
	else
		debugMsg "Using alphaBlending"
		img.alphaBlending = true	
		img.transparent( Background )
	end

	# Fill the image with the background and draw the text and a border with
	# the foreground color.
	debugMsg "Filling background"
	img.fill( 1, 1, Background )
	debugMsg "Drawing string"
	img.stringFT( Foreground, font, pointsize, 0, 5 - brect[6], 5 - brect[7], text )
	debugMsg "Filled and set string."

	return img
end


Background= GD::Image.trueColorAlpha( "#ffffff", GD::AlphaTransparent )
Foreground = GD::Image.trueColorAlpha( "#000000", GD::AlphaOpaque )
Fonts = load_fonts( "/Library/WebServer/Fonts" )

try( "imgetxt" ) do
	img = make_image( "Moonglow-Regular", 72, "72 Pt. Moonglow.png" )
	File.open( "moonglow-72.png", File::WRONLY|File::TRUNC|File::CREAT ) do |ofh|
		ofh.print( img.pngStr )
	end

	img
end





