#!/usr/bin/ruby
# 
# This file contains the ArrowWiki class, a derivative of Arrow::Applet. It's a
# simple wiki to demonstrate the Arrow framework.
# 
# == Rcsid
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

InstikiBase = "/Library/Instiki"
%w[ /libraries/ /app/models /app/controllers ].each do |dir|
	$LOAD_PATH.unshift( File::join(InstikiBase, dir) )
end

require 'wiki_service'

require 'arrow/applet'


### It's a simple wiki that can serve as a proof of concept
class WikiApplet < Arrow::Applet

	# Applet signature
	Signature = {
		:name => "Arrow Wiki Toplevel Applet",
		:description => "A wiki for FaerieMUD documentation",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'index',
		:templates => {
			:main		=> 'wiki/main.tmpl',
			:new_system => 'wiki/new_system.tmpl',
		},

		:vargs => {
			:create_system => {
				:untaint_all_constraints => true,
				:required       => [:password, :web_name, :web_address],
                :constraints    => {
                    :password		=> /^([\x20-\x7e]+)$/,
                    :web_name		=> /^([\x20-\x7f]+)$/,
					:web_address	=> /^([a-z0-9]+)$/i,
                },
			}
		},
	}

	# Default location for the wiki storage
	DefaultStoragePath = "/tmp/wikiapplet"


	### Create a new wiki controller applet.
	def initialize( *args )
		super

		# Read configuration values from the config file if it exists
		if @config.respond_to?( :wiki )
			wconfig = @config.wiki
			WikiService.storage_path = wconfig.storage
		else
			WikiService.storage_path = DefaultStoragePath
		end
	end


	######
	public
	######

	# Notes:
	#
	#   In instiki the action is stuck between the web and the topic like:
	#     /<web>/view/<topic>
	#   In this implementation the action always precedes the data, like so:
	#     /view/<web>/<topic>
	#   This might require tinkering a bit with the WikiService's innards, as I
	#   don't know if its link-builder is coupled with its internal urispace,
	#   but I suspect it is.

	### Debugging action /inspect
	def inspect_action( txn, *args )
		txn.content_type = "text/plain"
		return "%p: %d" % [ self.wiki, Process::pid ]
	end


	### Default "/" action -- redirects to the system init if the wiki's not yet
	### set up, redirects to the web list if there are more than one web, or
	### redirects to the home page if there's only one web.
	def index_action( txn, web=nil, *args )
		if !self.wiki.setup?
			return txn.redirect( txn.action + "/new_system/" )
		elsif self.wiki.webs.length == 1
			return txn.redirect( txn.action + "/show/" +
				self.wiki.webs.values.first.address )
		else
			return txn.redirect( txn.action + "/web_list/" )
		end
	end


	### /new_system action -- Initializes a new wiki.
	def new_system_action( txn, *args )
		if self.wiki.setup?
			return txn.redirect( txn.action )
		end

		tmpl = self.loadTemplate( :new_system )
		tmpl.txn = txn
		tmpl.applet = self
		tmpl.wiki = self.wiki

		return tmpl
	end


	### /create_system action -- the target for the /new_system action's
	### form. Untaints the incoming arguments, does the creation of the new wiki
	### if they check out, or displays /new_system's template again with errors
	### if the args were bad.
	def create_system_action( txn, *args )
		if !(txn.vargs.missing.empty? && txn.vargs.invalid.empty?)
			badargs = txn.vargs.missing | txn.vargs.invalid.keys
			self.log.error "Invalid or missing arguments: %p" % badargs

			tmpl = self.new_system_action( txn )
			badargs.each do |field|
				tmpl.errors << "Invalid or missing field '#{field}'"
			end

			return tmpl
		else
			vargs = txn.vargs
			self.log.info "Creating new web with args: %p" % [ vargs.valid.to_a ]

			self.wiki.setup( vargs[:password], vargs[:web_name], vargs[:web_address] ) unless
				self.wiki.setup?

			return txn.redirect( txn.action + "/new/" + vargs[:web_address] + "/HomePage" )
		end
	end


	def new_action( txn, web=nil, topic=nil, *args )
		txn.redirect( txn.action ) unless web
		txn.redirect( txn.action + "/show/" + web ) unless topic

		txn.content_type = "text/plain"
		return "Would be creating the '%s' topic of the '%s' web." % [ topic, web ]
	end

	def show_action( txn, web=nil, topic="HomePage", *args )
		txn.redirect( txn.action ) unless web

		txn.content_type = "text/plain"
		return "Would be showing the '%s' topic of the '%s' web." % [ topic, web ]
	end

	def web_list_action( txn, *args )
		txn.content_type = "text/plain"
		return "Would be listing the available webs"
	end


	#########
	protected
	#########


	### Return the WikiService instance
	def wiki
		WikiService.instance
	end


end # class ArrowWiki


