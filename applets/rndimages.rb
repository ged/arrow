#!/usr/bin/ruby
# 
# This file contains the RandomImages class, a derivative of Arrow::Applet. It
# shows the 'latest images' feed from LiveJournal as a page full of clickable
# links.
# 
# == Subversion Id
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

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

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
	Image = Struct::new( "RandomImage", :src, :href )


	# Applet signature
	Signature = {
		:name => "Random image gallery",
		:description => "Shows the 'latest images' feed from LiveJournal as " +
			"a page full of clickable links.",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'display',
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
		end

		feeduri ||= DefaultFeedUrl
		@feeduri = URI::parse( feeduri )

		@cache_seconds ||= DefaultCacheSeconds
		@cache_expiry = Time::at( 0 )
		@images = []
	end



	######
	public
	######

	action( 'display' ) {|txn, *args|
		if @cache_expiry < Time::now
			self.log.debug "Cached images expired at %s: Fetching new list" %
				[ @cache_expiry ]
			@images = self.build_imagelist( @feeduri )
			@cache_expiry = Time::now + @cache_seconds
		end

		tmpl = self.loadTemplate( :display )
		tmpl.txn = txn
		tmpl.app = self
		tmpl.images = @images

		return tmpl
	}



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

		Net::HTTP::start( uri.host, uri.port ) do |http|
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
			images << Image::new( $1, $2 )
		end

		self.log.debug "Parsed images: %p ..." % images[0..3]
		return images
	end


end # class RandomImages

