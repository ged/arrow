#!/usr/bin/ruby
# 
# This file contains the TemplateViewer class, a derivative of
# Arrow::Application. It is an introspection application that displays
# information about Arrow templates.
# 
# == Rcsid
# 
# $Id: view-template.rb,v 1.3 2003/12/24 09:04:56 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 

require 'arrow/application'
require 'arrow/htmltokenizer'

### An Arrow appserver status application.
class TemplateViewer < Arrow::Application

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.3 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: view-template.rb,v 1.3 2003/12/24 09:04:56 deveiant Exp $

	# Application signature
	Signature = {
		:name => "Template Viewer",
		:description => "It is an introspection application that displays "\
			"Arrow templates with syntax highlighting.",
		:uri => "view-template",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'default',
		:templates => {
			:display	=> 'view-template.tmpl',
			:default	=> 'templateviewer.tmpl',
		},
		:vargs => {
			:__default__ => {
				:optional		=> [:template],
				:constraints	=> {
					:username	=> %r{^([\w/](?:[\w/]|\.(?!\.)))$},
				},
				:untaint_constraint_fields => %w{template},
			},
		}
	}



	######
	public
	######


	#################################################################
	###	A C T I O N S
	#################################################################
	
	action( 'display' ) {|txn, *args|
		self.log.debug "In the 'display' action of the '%s' app." %
			self.signature.name 

		templ = txn.templates[:display]
		templ.txn = txn
		templ.app = self

		if txn.vargs && txn.vargs[:template]
			args.replace( txn.vargs[:template].split(%r{/}) )
		end
		
		# Eliminate harmful parts of the path and try to load the template
		# specified by it
		self.log.debug "Args: %p" % [ args ]
		args.reject! {|dir|
			dir.nil? || dir.empty? || /^\./ =~ dir || /[^-\w.]/ =~ dir
		}
		tpath = File::join( *args ).untaint
		templ.path = tpath

		unless tpath.empty?
			begin
				dtempl = self.templateFactory.getTemplate( tpath )
			rescue Arrow::TemplateError => err
				templ.error = err
			else
				templ.template = dtempl
				templ.tokenizer = Arrow::HTMLTokenizer::new( dtempl._source )
			end
		end

		txn.print( templ )

		return true
	}


end # class TemplateViewer


