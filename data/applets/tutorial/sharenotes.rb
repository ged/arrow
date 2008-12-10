#!/usr/bin/env ruby
# 
# The ShareNotes class, a derivative of Arrow::Applet. Render
# a shared document after being transformed via Markdown
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
require 'bluecloth'

### Render a shared document after being transformed via Markdown
class ShareNotes < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Default share directory
	DefaultDirectory = "/Users/ged/Documents"


	# Applet signature
	Signature = {
		:name => "sharenotes",
		:description => "Render a shared document after being transformed via Markdown",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'display',
		:templates => { 
			:display => "sharenotes/display.tmpl"
		}
	}


	def initialize( *args )
		super

		if @config.respond_to?( :sharenotes )
			@directory = @config.sharenotes.directory
		end

		@directory ||= DefaultDirectory
	end


	######
	public
	######

	def display_action( txn, *args )
		self.log.debug "In the 'display' action of the '%s' app." %
			self.signature.name 

		doc = $1 if /(\w[\w. -]+)/.match( args.first )
		doc.untaint

		tmpl = self.load_template( :display )

		begin
			if doc
				if File.readable?( doc )
					markdown = File.read( doc )
					tmpl.body = BlueCloth.new( markdown ).to_html
				else
					tmpl.error = "File '%s' is not readable." % [doc]
				end
			else
				tmpl.error = "No document specified"
			end
		rescue RuntimeError => err
			tmpl.error = err.message
		end
		

		return true
	end


end # class ShareNotes


