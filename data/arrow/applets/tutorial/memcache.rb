#!/usr/bin/env ruby
# 
# The MemCache class, a derivative of Arrow::Applet. This is a web interface to MemCached.
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
require 'memcache'

### This is a web interface to MemCached.
class MemCacheApplet < Arrow::Applet


	# Applet signature
	Signature = {
		:name => "memcache",
		:description => "This is a web interface to MemCached.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'display',
		:templates => {
			:display => 'memcache/display.tmpl',
		},
	}

	DefaultServers = [ 'localhost:11211' ]

	def initialize( *args )
		super

		servers = DefaultServers
		if @config.respond_to?( :memcache )
			servers.replace( @config.memcache.servers )
		end

		@memcache = MemCache.new( *servers )
	end


	######
	public
	######

	def display_action( txn, *args )
		templ = self.load_template( :display )
		templ.txn = txn
		templ.memcache = @memcache

		return templ
	end


end # class MemCache


