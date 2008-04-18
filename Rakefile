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


PKG_NAME      = 'arrow'
PKG_VERSION   = Arrow::VERSION
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

PKG_SUMMARY   = "Arrow - A Ruby web application framework"

RELEASE_NAME  = "REL #{PKG_VERSION}"

BASEDIR       = Pathname.new( __FILE__ ).dirname
DOCSDIR       = BASEDIR + 'docs' 
MANUALDIR     = DOCSDIR + 'manual'
APIDOCSDIR    = DOCSDIR + 'api'

TESTDIR       = BASEDIR + 'tests'
TEST_FILES    = Pathname.glob( TESTDIR + '**/*.tests.rb' ).
	delete_if {|item| item =~ /\.svn/ }

SPECDIR       = BASEDIR + 'spec'
SPEC_FILES    = Pathname.glob( SPECDIR + '**/*_spec.rb' ).
	delete_if {|item| item =~ /\.svn/ }

LIBDIR        = BASEDIR + 'lib'
LIB_FILES     = Pathname.glob( LIBDIR + '**/*.rb' )	.
	delete_if {|item| item =~ /\.svn/ }

TEXT_FILES    = %w( Rakefile README )

RELEASE_FILES = TEXT_FILES + LIB_FILES + SPEC_FILES


# Load task plugins
RAKE_TASKDIR = BASEDIR + 'rake'
Pathname.glob( RAKE_TASKDIR + '*.rb' ).each do |tasklib|
	begin
		require tasklib
	rescue => err
		fail "Tasklib #{tasklib}: #{err.message}"
	end
end

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


### Task: manual
Manual::GenTask.new( :manual ) do |manual|
	manual.metadata.version = PKG_VERSION
	manual.metadata.gemspec = GEMSPEC
	manual.base_dir = MANUALDIR
	manual.output_dir = 'output'
end
task :manual => [ :rdoc ] do
	log "Copying API docs into the manual output"
	
	apidocs = FileList[ APIDOCSDIR + '**/*' ]
	copydocs = apidocs.pathmap( '%{^docs/}p' )
end


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


