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

require 'bdb'
require 'test/unit'

# Prevent Test::Unit from autorunning from its own at_exit
at_exit { Test::Unit.run = true }


### The UnitTest applet can be used to define and run tests for another applet
### by chaining through it.
class UnitTester < Arrow::Applet

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Default options for the BDB::Env object
	EnvOptions = {
		:set_timeout	=> 50,
		:set_lk_detect	=> 1,
		:set_verbose	=> true,
	}

	# Default flags for the BDB::Env object
	EnvFlags = BDB::CREATE|BDB::INIT_TRANSACTION|BDB::RECOVER

	# Applet signature
	Signature = {
		:name => "Unit testing applet",
		:description => "The UnitTest applet can be used to define and run " +
			"tests for another applet by chaining through it.",
		:uri => "/test",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'list',
		:templates => {
			:list			=> 'test/list.tmpl',
			:testharness	=> "test/harness.tmpl",
			:problem		=> "test/problem.tmpl",
		},
	}


	### Create a new instance of the UnitTester applet with the specified
	### +config+. It will look for its configuration values in the top-level
	### 'unittester' key if there is one.
	def initialize( *args )
		super

		@dbenv = nil
		@initError = nil

		# If the app is configured in the config file, then load the database.
		if @config.respond_to?( :unittester ) && false
			begin
				envdir = @config.unittester.dbenv
				Dir.mkdir( envdir, 0755 ) if !File.exists?( envdir )
				@dbenv = BDB::Env.create( envdir, EnvFlags, EnvOptions )
			rescue Exception => err
				@initError = err
			end
		else
			@initError = [
				"Not Configured",
				"The 'unittester' section was not present or malformed in " +
				@config.name + ". It should contain, at a minimum, a 'dbenv' item " +
				"which specifies the path to the test database."
			]
		end

	end



	######
	public
	######

	# Run tests for the applet/s next in the chain
	def delegate( txn, chain, *args )
		return reportProblem( txn ) unless @dbenv

		app = chain.last
		tests = @dbenv.open_db( BDB::Hash, app[0].signature.name.gsub(/\W+/, '_'), nil, BDB::CREATE )

		templ = self.load_template( :testharness )
		templ.txn = txn
		templ.tests = tests

		return templ
	end


	# List the applets for which tests have been defined so far.
	def_action :list do |txn, *args|
		return reportProblem( txn ) unless @dbenv

		templ = self.load_template( :list )
		templ.txn = txn
		return templ
	end

	
	# Auxilliary action: report a problem while loading the test harness.
	def reportProblem( txn )
		templ = self.load_template( :problem )
		templ.err = @initErr

		return templ
	end



	#################################################################
	###	T E S T   H A R N E S S   C L A S S E S
	#################################################################

	class TestRunner
		extend Test::Unit::UI::TestRunnerUtilities

		
	end

end # class UnitTester

