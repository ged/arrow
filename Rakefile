#!rake
#
# Arrow rakefile
#
# Originally based on Ben Bleything's Rakefile for Linen
#
# Copyright (c) 2007, 2008 The FaerieMUD Consortium
#
# Authors:
#  * Michael Granger <ged@FaerieMUD.org>
#  * Jeremiah Jordan <phaedrus@FaerieMUD.org>
#

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname

	libdir = basedir + 'lib'
	docsdir = basedir + 'docs'

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
	$LOAD_PATH.unshift( docsdir.to_s ) unless $LOAD_PATH.include?( docsdir.to_s )
}


require 'rbconfig'
require 'rubygems'
require 'rake'
require 'pathname'
require 'apache/fakerequest'

begin
	require 'arrow'
rescue LoadError => err
	$stderr.puts "Arrow didn't load cleanly: #{err.message}"
end

include Config


PKG_NAME        = 'arrow'
PKG_VERSION     = Arrow::VERSION
PKG_FILE_NAME   = "#{PKG_NAME.capitalize}-#{PKG_VERSION}"

PKG_SUMMARY     = "Arrow - A Ruby web application framework"

RELEASE_NAME    = PKG_FILE_NAME

BASEDIR         = Pathname.new( __FILE__ ).dirname.expand_path.relative_path_from( Pathname.getwd )
DOCSDIR         = BASEDIR + 'docs' 
MANUALDIR       = DOCSDIR + 'manual'
MANUALOUTPUTDIR = MANUALDIR + 'output'
APIDOCSDIR      = DOCSDIR + 'api'

TESTDIR         = BASEDIR + 'tests'
TEST_FILES      = Pathname.glob( TESTDIR + '**/*.tests.rb' ).
	delete_if {|item| item =~ /\.svn/ }

SPECDIR         = BASEDIR + 'spec'
SPEC_FILES      = Pathname.glob( SPECDIR + '**/*_spec.rb' ).
	delete_if {|item| item =~ /\.svn/ }

LIBDIR          = BASEDIR + 'lib'
LIB_FILES       = Pathname.glob( LIBDIR + '**/*.rb' ).
	delete_if {|item| item =~ /\.svn/ }

TEXT_FILES      = %w( Rakefile README )

RELEASE_FILES   = TEXT_FILES + LIB_FILES + SPEC_FILES


# Documentation constants
RDOC_OPTIONS = [
	'-w', '4',
	'-SHN',
	'-i', '.',
	'-m', 'README',
	'-W', %Q{http://deveiate.org/projects/#{PKG_NAME.capitalize}/browser/trunk/}
  ]

# Release constants
SMTP_HOST = 'mail.faeriemud.org'
SMTP_PORT = 465 # SMTP + SSL

# Project constants
PROJECT_HOST = 'deveiate.org'
PROJECT_PUBDIR = "/usr/local/www/public/code"
PROJECT_PUBURL = "#{PROJECT_HOST}:#{PROJECT_PUBDIR}"
PROJECT_DOCDIR = "#{PROJECT_PUBDIR}/#{PKG_NAME}"
PROJECT_DOCURL = "#{PROJECT_HOST}:#{PROJECT_DOCDIR}"

# RubyGem specification
GEMSPEC = Gem::Specification.new do |gem|
	gem.name    	= PKG_NAME
	gem.version 	= PKG_VERSION

	gem.summary     = PKG_SUMMARY
	gem.description = <<-EOD
	Arrow is a web application framework for mod_ruby. It was designed to make
	development of web applications under Apache easier and more fun without
	sacrificing the power of being able to access the native Apache API.
	EOD

	gem.authors  	= "Michael Granger, Martin Chase, Dave McCorkhill, Jeremiah Jordan"
	gem.email       = "ged@FaerieMUD.org"
	gem.homepage 	= "http://deveiate.org/projects/Arrow"
	gem.rubyforge_project = 'deveiate'

	gem.has_rdoc 	= true

	gem.files      	= RELEASE_FILES.collect {|pn| pn.to_s }
	gem.test_files 	= [ SPEC_FILES + TEST_FILES ].flatten.collect {|pn| pn.to_s }

	gem.requirements << "mod_ruby >= 1.2.6"

  	gem.add_dependency( 'ruby-cache', '>= 0.3.0' )
  	gem.add_dependency( 'formvalidator', '>= 0.1.3' )
  	gem.add_dependency( 'pluginfactory', '>= 1.0.2' )
end

# Load task plugins
RAKE_TASKDIR = BASEDIR + 'rake'
Pathname.glob( RAKE_TASKDIR + '*.rb' ).each do |tasklib|
	next if tasklib =~ %r{/helpers.rb$}
	begin
		require tasklib
	rescue ScriptError => err
		fail "Task library '%s' failed to load: %s: %s" %
			[ tasklib, err.class.name, err.message ]
		trace "Backtrace: \n  " + err.backtrace.join( "\n  " )
	rescue => err
		log "Task library '%s' failed to load: %s: %s. Some tasks may not be available." %
			[ tasklib, err.class.name, err.message ]
		trace "Backtrace: \n  " + err.backtrace.join( "\n  " )
	end
end

# Define some constants that depend on the 'svn' tasklib
PKG_BUILD = get_svn_rev( BASEDIR ) || 0
SNAPSHOT_PKG_NAME = "#{PKG_FILE_NAME}.#{PKG_BUILD}"
SNAPSHOT_GEM_NAME = "#{SNAPSHOT_PKG_NAME}.gem"

# Support old-style trace and dryrun
if Rake.application.options.trace
	$trace = true
	log "$trace is enabled"
else
	$trace = false
end

if Rake.application.options.dryrun
	$dryrun = true
	log "$dryrun is enabled"
else
	$dryrun = false
end


### Default task
task :default  => [:all_tests, :docs, :package]

### New and legacy tests
task :all_tests => ["spec:quiet", :test]

### Documentation task
task :docs do
	log "Building API docs"
	Rake::Task[:rdoc].invoke
	log "Building the manual"
	Rake::Task[:manual].invoke
end

### Task: clean
desc "Clean pkg, coverage, and rdoc; remove .bak files"
task :clean => [ :clobber_rdoc, :clobber_manual, :clobber_package, 'coverage:clobber' ] do
	files = FileList['**/*{.bak,~}']
	files.clear_exclude
	rm( files, :verbose => true ) unless files.empty?
end


### Task: rdoc
begin
	gem 'darkfish-rdoc'
	require 'rake/rdoctask'
	
	Rake::RDocTask.new do |rdoc|
		rdoc.rdoc_dir = APIDOCSDIR.to_s
		rdoc.title    = "Arrow #{PKG_VERSION}"

		rdoc.options += [
			'-w', '4',
			'-SHN',
			'-i', 'docs',
			'-f', 'darkfish',
			'-m', 'README',
			'-W', 'http://deveiate.org/projects/Arrow/browser/trunk/'
		  ]
	
		rdoc.rdoc_files.include 'README'
		rdoc.rdoc_files.include LIB_FILES.
			collect {|file| file.relative_path_from(BASEDIR).to_s }
	end
	
rescue LoadError => err
	task :no_rdoc do
		$stderr.puts "API documentation tasks not defined: %s" % [ err.message ]
	end
	
	task :rdoc => :no_rdoc
end


### Copy method for resources -- passed as a block to the various file tasks that copy
### resources to the output directory.
def copy_resource( task )
	source = task.prerequisites[ 1 ]
	target = task.name
	
	when_writing do
		log "  #{source} -> #{target}"
		mkpath File.dirname( target )
		cp source, target, :verbose => $trace
	end
end
	

### Task: manual
Manual::GenTask.new( :manual ) do |manual|
	manual.metadata.version = PKG_VERSION
	manual.metadata.gemspec = GEMSPEC
	manual.base_dir = MANUALDIR
	manual.output_dir = MANUALOUTPUTDIR
end
begin
	apidocs = FileList[ APIDOCSDIR + '**/*' ]
	# trace "  apidocs: %p" % [ apidocs ]
	targets = apidocs.pathmap( "%%{#{APIDOCSDIR},%s}p" % [ MANUALOUTPUTDIR + 'api' ] )
	# trace "  mapped apidocs to targets: %p" % [ targets ]
	copier = self.method( :copy_resource ).to_proc
	
	# Create a file task to copy each file to the output directory
	apidocs.each_with_index do |docsfile, i|
		file( targets[i] => [ MANUALOUTPUTDIR.to_s, docsfile ], &copier )
	end

	# Now group all the API doc copy tasks into a containing task
	desc "Copy API documentation to the output directory"
	task :copy_apidocs => targets
end

task :manual => :copy_apidocs
directory MANUALOUTPUTDIR.to_s

### Task: install
desc "Install Arrow as a conventional library"
task :install do
	log "Installing Arrow as a convention library"
	sitelib = Pathname.new( CONFIG['sitelibdir'] )
	Dir.chdir( LIBDIR ) do
		LIB_FILES.each do |libfile|
			relpath = libfile.relative_path_from( LIBDIR )
			target = sitelib + relpath
			FileUtils.mkpath target.dirname,
				:mode => 0755, :verbose => true, :noop => $dryrun unless target.dirname.directory?
			FileUtils.install relpath, target,
				:mode => 0644, :verbose => true, :noop => $dryrun
		end
	end
end

### Task: install_gem
desc "Install Arrow as a gem"
task :install_gem => [:package] do
	installer = Gem::Installer.new( %{pkg/#{PKG_FILE_NAME}.gem} )
	installer.install
end

### Task: uninstall
desc "Uninstall Arrow if it's been installed as a conventional library"
task :uninstall do
	log "Uninstalling conventionally-installed Arrow library files"
	sitelib = Pathname.new( CONFIG['sitelibdir'] )
	dir = sitelib + 'arrow'
	FileUtils.rm_rf( dir, :verbose => true, :noop => $dryrun )
	lib = sitelib + 'arrow.rb'
	FileUtils.rm( lib, :verbose => true, :noop => $dryrun )
end

### Task: uninstall_gem
task :uninstall_gem => [:clean] do
	uninstaller = Gem::Uninstaller.new( PKG_FILE_NAME )
	uninstaller.uninstall
end


