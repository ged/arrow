#!/usr/bin/ruby
# 
# This file contains the TemplateViewer class, a derivative of
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

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Applet signature
	Signature = {
		:name => "Template Viewer",
		:description => "It is an introspection applet that displays "\
			"Arrow templates with syntax highlighting.",
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
		self.log.debug "In the 'display' action of the '%s' applet." %
			self.signature.name 

		templ = self.loadTemplate( :display )
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
		tpath = File::join( *args ).untaint
		templ.path = tpath

		unless tpath.empty?
			begin
				dtempl = self.getTemplate( tpath )
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


