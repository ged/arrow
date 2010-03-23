#!/usr/bin/env ruby
# 
# The RandomImages class, a derivative of Arrow::Applet. It
# shows the 'latest images' feed from LiveJournal as a page full of clickable
# links.
# 
# == VCS Id
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'uri'
require 'net/http'

require 'arrow/applet'

### It shows the 'latest images' feed from LiveJournal as a page full of clickable links.
class RandomImages < Arrow::Applet


	# Default feed URL if none is configured
	DefaultFeedUrl = 'http://www.livejournal.com/stats/latest-img.bml'

	# Default number of seconds to cache the image list
	DefaultCacheSeconds = 15 * 60

	# Recent-image entry pattern
	RecentImagePattern = %r{
		<recent-image			# Tag open
		  \s+					# whitespace
		 img='([^']+)'			# $1 = image URL
		  \s+					# whitespace
		 url='([^']+)'			# $2 = link URL
		  \s*					# whitspace
		/>						# Tag close
	}x

	# Image struct
	Image = Struct.new( :src, :href )

	# Default number of images to display from the feed at a time
	DefaultImageCount = 15

	# Applet signature
	Signature = {
		:name => "Random image gallery",
		:description => "Shows the 'latest images' feed from LiveJournal as " +
			"a page full of clickable links.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'display',
		:templates => {
			:display	=> 'rndimages.tmpl',
		}
	}


	### Set up the random image gallery.
	def initialize( *args )
		super

		if @config.respond_to?( :rndimages )
			feeduri = @config.rndimages.feedurl
			@cache_seconds = Integer( @config.rndimages.cacheseconds ) rescue nil
			@count = Integer( @config.rndimages.displaycount ) rescue nil
		end

		feeduri ||= DefaultFeedUrl
		@feeduri = URI.parse( feeduri )

		@cache_seconds ||= DefaultCacheSeconds
		@cache_expiry = Time.at( 0 )
		@count ||= DefaultImageCount
		@images = []
	end



	######
	public
	######

	def_action :display do |txn, *args|
		if @cache_expiry < Time.now
			self.log.debug "Cached images expired at %s: Fetching new list" %
				[ @cache_expiry ]
			@images = self.build_imagelist( @feeduri )
			@cache_expiry = Time.now + @cache_seconds
		end

		imgslice = []
		until imgslice.nitems == @count
			imgslice << rand( @images.nitems )
			imgslice.uniq!
		end

		tmpl = self.load_template( :display )
		tmpl.txn = txn
		tmpl.app = self
		tmpl.images = @images.values_at( *imgslice )

		return tmpl
	end



	#########
	protected
	#########

	### Fetch the list of images in the feed and replace the ones currently in
	### @images, if any.
	def build_imagelist( feeduri )
		rawfeed = self.fetch_imagefeed( feeduri )
		images = self.parse_imagefeed( rawfeed )

		return images
	end


	### Fetch the raw imagelist over HTTP and return it. An exception is raised
	### if the fetch fails for some reason.
	def fetch_imagefeed( uri )
		res = nil

		Net::HTTP.start( uri.host, uri.port ) do |http|
			res = http.get( uri.path )
		end

		unless Net::HTTPSuccess === res
			raise "Fetch of %s failed: %d: %s" %
				[ uri, res.code, res.message ]
		end

		return res.body
	end


	### Parse the given +rawdata+ from the image feed and return an Array of
	### Hashes that describe the images referenced therein.
	def parse_imagefeed( rawdata )
		images = []

		rawdata.scan( RecentImagePattern ) do |match|
			self.log.debug "Matched image tag: %p" % match
			images << Image.new( $1, $2 )
		end

		self.log.debug "Parsed images: %p ..." % images[0..3]
		return images
	end


end # class RandomImages


