#!/usr/bin/env ruby
# 
# The TemplateViewer class, a derivative of
# Arrow::Applet. It is an introspection applet that displays information about
# Arrow templates.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/applet'
require 'arrow/htmltokenizer'

### A template viewer applet
class TemplateViewer < Arrow::Applet


	# Applet signature
	applet_name "Template Viewer"
	applet_description "It is an introspection applet that displays "\
			"Arrow templates with syntax highlighting."
	applet_maintainer "ged@FaerieMUD.org"

	default_action :default



	######
	public
	######


	#################################################################
	###	A C T I O N S
	#################################################################
	
	def display_action( txn, *args )
		self.log.debug "In the 'display' action of the '%s' applet." %
			self.signature.name 

		templ = self.load_template( :display )
		templ.txn = txn
		templ.applet = self

		if txn.vargs && txn.vargs[:template]
			args.replace( txn.vargs[:template].split(%r{/}) )
		end
		
		# Eliminate harmful parts of the path and try to load the template
		# specified by it
		self.log.debug "Args: %p" % [ args ]
		args.reject! {|dir|
			dir.nil? || dir.empty? || /^\./ =~ dir || /[^-\w.]/ =~ dir
		}
		tpath = File.join( *args ).untaint
		templ.path = tpath

		unless tpath.empty?
			begin
				dtempl = self.templateFactory.get_template( tpath )
			rescue Arrow::TemplateError => err
				templ.error = err
			else
				templ.template = dtempl
				templ.tokenizer = Arrow::HTMLTokenizer.new( dtempl._source )
			end
		end

		return templ
	end
	template :display	=> 'view-template.tmpl',
		:default	=> 'templateviewer.tmpl'
	validator :display, {
		:optional		=> [:template],
		:constraints	=> {
			:template	=> %r{^([\w./-]+)$},
		},
		:untaint_constraint_fields => %w{template},
	}


end # class TemplateViewer


