#!/usr/bin/env ruby
# 
# The AppletViewer class, a derivative of Arrow::Applet. It is
# an introspection applet that can be used to view the code for Arrow applets in
# a running Arrow application.
# 
# == Subversion Id
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/applet'


### An introspection applet that can be used to view the code for Arrow
### applets in a running Arrow application.
class AppletViewer < Arrow::Applet


	# Width of tabs in prettified code
	DefaultTabWidth = 4

	# Applet signature
	Signature = {
		:name => "Applet Viewer",
		:description => "An introspection applet that can be used to view the " +
			"code for Arrow applets in a running Arrow application.",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'display',
		:templates => {
			:display	=> 'view-applet.tmpl',
			:nosuch		=> 'view-applet-nosuch.tmpl',
		},
	}


	### Read configuration values from the 'viewapplet' section of the config
	### (if it exists)
	def initialize( *args )
		super

		@tabwidth = DefaultTabWidth

		if @config.respond_to?( :viewapplet )
			@tabwidth = Integer( @config.viewapplet.tabwidth ) rescue DefaultTabWidth
		end

		self.log.debug "Tab width set to %d" % @tabwidth
	end


	######
	public
	######

	### The main applet-code display action
	def display_action( txn, *appleturi )
		self.log.debug "In the 'display' action of the '%s' app." % self.signature.name 

		# Pick out the applet to view from the URI, if present
		templ = nil
		uri = appleturi.join( "/" )
		applet = txn.broker.registry[ uri ]

		# If the URI matched a loaded applet, display its source
		if applet

			# The applet's class knows from whence it was loaded.
			fn = applet.class.filename
			fn.untaint

			# Plug the loaded values into the template
			templ = self.load_template( :display )
			templ.displayed_applet = applet
			templ.filename = fn

			# Read the code. This will later undergo some sort of greater
			# fancification.
			code = File.read( fn )
			templ.code = self.format_code( code )
			
		else

			# If there wasn't an applet to load, load the generic "oops"
			# template and plug a message in.
			templ = self.load_template( :nosuch )
			templ.message = "Invalid or missing applet URI"
		end

		# Plug some more values into the template no matter what happened
		templ.txn = txn
		templ.applet = self

		return templ
	end

	# Allow <uri>/<viewuri> as well as <uri>/display/<viewuri>
	alias_method :action_missing_action, :display_action


	#########
	protected
	#########

	### Format the code prettily for display as HTML
	def format_code( code )
		newstr = code.split( /\n/ ).collect {|line|
			line.gsub( /(.*?)\t/ ) do
				$1 + ' ' * (@tabwidth - $1.length % @tabwidth)
			end
		}.join("\n")

		return newstr
	end


end # class AppletViewer


