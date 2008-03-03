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


require 'rubygems'
require 'rake'
require 'pathname'
require 'apache/fakerequest'

begin
	require 'arrow'
rescue LoadError => err
	$stderr.puts "Arrow didn't load cleanly: #{err.message}"
end


PKG_NAME      = 'arrow'
PKG_VERSION   = Arrow::VERSION
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

PKG_SUMMARY   = "Arrow - A Ruby web application framework"

RELEASE_NAME  = "REL #{PKG_VERSION}"

BASEDIR       = Pathname.new( __FILE__ ).dirname
LIBDIR        = BASEDIR + 'lib'
DOCSDIR       = BASEDIR + 'docs' 
MANUALDIR     = DOCSDIR + 'manual'
APIDOCSDIR    = DOCSDIR + 'api'

TEXT_FILES    = %w( Rakefile README )
TEST_FILES    = FileList[ 'tests/**/*.tests.rb' ]
TEST_FILES.exclude( /\.svn/ )
SPEC_FILES    = FileList[ 'spec/**/*_spec.rb' ]
SPEC_FILES.exclude( /\.svn/ )
LIB_FILES     = FileList[ 'lib/**/*.rb' ]
LIB_FILES.exclude( /\.svn/ )

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
task :docs => [ :rdoc, :manual ]

### Task: clean
desc "Clean pkg, coverage, and rdoc; remove .bak files"
task :clean => [ :clobber_rdoc, :clobber_manual, :clobber_package, 'coverage:clobber' ] do
	files = FileList['**/*.bak']
	files.clear_exclude
	File.rm( files ) unless files.empty?
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
		rdoc.rdoc_files.include LIB_FILES
	end
	
rescue LoadError => err
	task :no_rdoc do
		$stderr.puts "API documentation tasks not defined: %s" % [ err.message ]
	end
	
	task :rdoc => :no_rdoc
end


### Task: manual
Manual::GenTask.new do |manual|
	manual.metadata.version = PKG_VERSION
	manual.metadata.gemspec = GEMSPEC
	manual.base_dir = MANUALDIR
end


### Installation tasks

desc "Install the library as a gem"
task :install_gem => [:spec, :gem] do
	installer = Gem::Installer.new( %{pkg/#{PKG_FILE_NAME}.gem} )
	installer.install
end

desc "Uninstall the gem"
task :uninstall_gem => [:clean] do
	uninstaller = Gem::Uninstaller.new( PKG_FILE_NAME )
	uninstaller.uninstall
end


