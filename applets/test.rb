#!/usr/bin/ruby
# 
# This file contains the UnitTester class, a derivative of
# Arrow::Applet. The UnitTest applet can be used to define and run tests for
# another applet by chaining through it.
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
#require 'test/unit/ui/testrunnermediator'
#require 'test/unit/ui/testrunnerutilities'

### The UnitTest applet can be used to define and run tests for another applet
### by chaining through it.
class UnitTester < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Applet signature
	Signature = {
		:name => "Unit testing applet",
		:description => "The UnitTest applet can be used to define and run " +
			"tests for another applet by chaining through it.",
		:uri => "/test",
		:maintainer => "ged@FaerieMUD.org",
		:defaultAction => 'list',
		:templates => {
			:list			=> 'test-list.tmpl',
			:testharness	=> "test-harness.tmpl",
		},
	}


	######
	public
	######

	# Run tests for the applet/s next in the chain
	def delegate( txn, chain, *args )
		templ = txn.template[ :testharness ]

		templ.txn = txn
		return templ
	end


	# List the applets for which tests have been defined so far.
	action( 'list' ) {|txn, *args|
		templ = txn.templates[ :list ]

		templ.txn = txn
		return templ
	}


end # class UnitTester


#Test::Unit::run = false
