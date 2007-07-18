#!/usr/bin/env ruby
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

require 'arrow/applet'


### It's a simple wiki that can serve as a proof of concept
class WikiApplet < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Applet signature
	Signature = {
		:name => "Arrow Wiki Toplevel Applet",
		:description => "A wiki for FaerieMUD documentation",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'index',
		:templates => {
			:main		=> 'wiki/main.tmpl',
			:new_system => 'wiki/new_system.tmpl',
			:show		=> 'wiki/show.tmpl',
			:new		=> 'wiki/new.tmpl',
			:save		=> 'wiki/save.tmpl',
			:formerror	=> 'wiki/formerror.tmpl',
		},

		:validator_profiles => {

			# Target for the form in /new_system
			:create_system => {
				:untaint_all_constraints => true,
				:required       => [:password, :web_name, :web_address],
                :constraints    => {
                    :password		=> /^([\x20-\xff]+)$/,
                    :web_name		=> /^([\x20-\xff]+)$/,
					:web_address	=> /^([a-z0-9]+)$/i,
                },
			},

			# Target for the forms in /edit and /new
			:save => {
				:untaint_all_constraints => true,
				:required       => [:author, :content],
                :constraints    => {
                    :author			=> /^([\x20-\xff]+)$/,
					:content		=> /^([\r\n\t\x20-\xff]+)$/,
                },
			},
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
		return "%p: %d" % [ self.wiki, Process.pid ]
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

		tmpl = self.load_template( :new_system )
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

			self.wiki.setup(
				vargs[:password],
				vargs[:web_name],
				vargs[:web_address] ) unless
				self.wiki.setup?

			return txn.redirect( txn.action + "/new/" + vargs[:web_address] +
				"/HomePage" )
		end
	end


	### /new/+web+/+topic+ -- create a new topic on the specified +web+ called
	### +topic+.
	def new_action( txn, web=nil, topic=nil, *args )
		return txn.redirect( txn.action ) unless web
		return txn.redirect( txn.action + "/show/" + web ) unless topic

		templ = self.load_template( :new )

		templ.txn = txn
		templ.topic = topic
		templ.web = web
		templ.author = txn.session[:author] || "AnonymousCoward"

		return templ
	end


	### /show/+web+/+topic+ -- Show the specified +topic+ from the given +web+.
	def show_action( txn, web=nil, topic="HomePage", *args )
		return txn.redirect( txn.action ) unless web

		self.log.debug "Showing '#{web}/#{topic}'"

		if page = self.wiki.read_page( web, topic )
			templ = self.load_template( :show )
			templ.txn = txn
			templ.web = web
			templ.page = page

			return templ
		else
			return txn.redirect( txn.applet + "/new/" + topic )
		end
	end


	### /save/+web+/+topic+ -- Save the values for the specified +topic+ to the
	### given +web+, creating it if it didn't already exist.
	def save_action( txn, web=nil, topic=nil, *args )
		self.log.debug "Save: web: %p, topic: %p" % [web, topic]
		return txn.redirect( txn.applet ) unless web
		return txn.redirect( txn.applet + "/show/" + web ) unless topic

		templ = nil
		txn.session[:wiki_author] = txn.vargs[:author] if txn.vargs.key?( :author )

		# If the arguments don't validate, fetch the template from the referring
		# action again and inject explanatory errors into it.
		return self.report_form_errors( txn, web, topic ) if txn.vargs.errors?

		webobj = self.wiki.webs[ web ] or return txn.redirect( txn.applet )
		author = Author.new( txn.vargs[:author], txn.remote_ip )
		self.log.debug "Save for web: %p, author: %p" % [webobj, author]
		
		# If it already exists, add a revision to the page
		if webobj.pages[ topic ]
			self.log.debug "Revising page '#{topic}'"
			page = self.wiki.
				revise_page( web, topic, txn.params[:content], Time.now, author )
			page.unlock

		# Otherwise it's a new page
		else
			self.log.debug "Creating page '#{topic}'"
			page = self.wiki.
				write_page( web, topic, txn.params[:content], Time.now, author )
		end

		return txn.redirect( txn.applet + "/" + ["show", web, topic].join("/") )
	end


	### /web_list -- List the webs that are available
	def web_list_action( txn, *args )
		txn.content_type = "text/plain"
		return "Would be listing the available webs"
	end


	#########
	protected
	#########


	### Call the referring action again, but add any validator error messages to
	### the returned template's 'formerrors' field.
	def report_form_errors( txn, web, topic, *args )
		templ = nil
		refaction = txn.referringAction
				
		if refaction && self.actions[ refaction ]
			templ = self.subrun( refaction, txn, web, topic, *args )
		else
			templ = self.load_template( :formerror )

			templ.txn = txn
			templ.applet = self
		end			

		templ.formerrors = txn.vargs.error_messages
		return templ
	end
	

	### Return the WikiService instance
	def wiki
		WikiService.instance
	end


end # class ArrowWiki


