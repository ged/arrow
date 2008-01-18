#!rake
#
# Arrow rakefile
#
# Based on Ben Bleything's Rakefile for Linen (URL?)
#
# Copyright (c) 2007 The FaerieMUD Consortium
#
# Mistakes:
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
gem 'rspec', '>= 1.0.4'

require 'rake'
require 'rake/testtask'
require 'rcov/rcovtask'
require 'spec/rake/spectask'
require 'spec/rake/verifytask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'pathname'

require 'apache/fakerequest'
require 'arrow'


PKG_NAME      = 'arrow'
PKG_VERSION   = Arrow::VERSION
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

PKG_SUMMARY   = "Arrow - A Ruby web application framework"

RELEASE_NAME  = "REL #{PKG_VERSION}"

BASEDIR       = Pathname.new( __FILE__ ).dirname.expand_path
LIBDIR        = BASEDIR + 'lib'

TEXT_FILES    = %w( Rakefile README )
SPEC_DIRS     = ['spec']
TEST_FILES    = FileList[ 'tests/**/*.tests.rb' ]
SPEC_FILES    = Dir.glob( 'spec/*_spec.rb' )
LIB_FILES     = Dir.glob('lib/**/*.rb').delete_if { |item| item =~ /\.svn/ }

RELEASE_FILES = TEXT_FILES + LIB_FILES + SPEC_FILES

# Load task plugins
RAKE_TASKDIR = BASEDIR + 'rake'
Pathname.glob( RAKE_TASKDIR + '*.rb' ).each do |tasklib|
	require tasklib
end

if Rake.application.options.trace
	$trace = true
	log "$trace is enabled"
end

if Rake.application.options.dryrun
	$dryrun = true
	log "$dryrun is enabled"
end




### Default task
task :default  => [:all_tests, :package]

### New and legacy tests
task :all_tests => [:test, "spec:quiet"]


### Task: test
Rake::TestTask.new do |task|
    task.libs << "test/lib"
    task.test_files = TEST_FILES
    task.verbose = true
end

### Task: spec
Spec::Rake::SpecTask.new( :spec ) do |task|
	task.spec_files = SPEC_FILES
	task.spec_opts = ['-c', '-f','s']
end


### Task: spec:autotest
namespace :spec do
	desc "Run rspec every time there's a change to one of the files"
	task :autotest do |t|
		basedir = Pathname.new( __FILE__ )
		$LOAD_PATH.unshift( LIBDIR ) unless $LOAD_PATH.include?( LIBDIR )

		require 'rspec_autotest'
		$v = true
		$vcs = 'svn'
		RspecAutotest.run
	end
	
	desc "Run rspec with default (quieter) output"
	Spec::Rake::SpecTask.new( :quiet ) do |task|
		task.spec_files = SPEC_FILES
		task.spec_opts = []
	end
	
	desc "Generate HTML output for a spec run"
	Spec::Rake::SpecTask.new( :html ) do |task|
		task.spec_files = SPEC_FILES
		task.spec_opts = ['-f','h']
	end
end


### Task: clean
desc "Clean pkg, coverage, and rdoc; remove .bak files"
task :clean => [ :clobber_rdoc, :clobber_package, :clobber_coverage ] do
	files = FileList['**/*.bak']
	files.clear_exclude
	File.rm( files ) unless files.empty?
end


### Task: rcov
desc "Build RSpec test coverage reports"
Spec::Rake::SpecTask.new( :spec_coverage ) do |task|
	task.spec_files = SPEC_FILES
	task.rcov_opts = ['--exclude', 'spec']
	task.rcov = true
	task.rcov_dir = 'spec_coverage'
end

desc "Build Test::Unit test coverage reports"
Rcov::RcovTask.new( :test_coverage ) do |task|
	task.test_files = TEST_FILES
	task.output_dir = 'test_coverage'
end

task :coverage => [:spec_coverage, :test_coverage]
task :clobber_coverage => [:clobber_spec_coverage, :clobber_test_coverage]

desc "Build coverage statistics"
VerifyTask.new( :verify => :coverage ) do |task|
	task.threshold = 85.0
end


### Task: rdoc
Rake::RDocTask.new do |rdoc|
	rdoc.rdoc_dir = 'docs/html'
	rdoc.title    = "The Arrow Web Application Framework"

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


### Task: install gems for development tasks
DEPENDENCIES = %w[formvalidator ruby-cache flexmock ruby-breakpoint]
task :install_dependencies do
	# Check for root
	if Process.euid != 0
		$deferr.puts "This probably won't work, as you aren't root, but I'll try anyway"
	end
	
	installer = Gem::RemoteInstaller.new( :include_dependencies => true )
	gemindex = Gem::SourceIndex.from_installed_gems
	
	DEPENDENCIES.each do |gemname|
		if (( specs = gemindex.search(gemname) )) && ! specs.empty?
			$deferr.puts "Version %s of %s is already installed; skipping..." % 
				[ specs.first.version, specs.first.name ]
			next
		end

		$deferr.puts "Trying to install #{gemname}..."
		gems = installer.install( gemname )
		gems.compact!
		$deferr.puts "Installed: %s" % [gems.collect {|spec| spec.full_name}.join(', ')]

		gems.each do |gem|
			Gem::DocManager.new( gem, '-w4 -SNH' ).generate_ri
			Gem::DocManager.new( gem, '-w4 -SNH' ).generate_rdoc
		end
	end
end


### Task: gem
gemspec = Gem::Specification.new do |gem|
	gem.name    	= PKG_NAME
	gem.version 	= PKG_VERSION

	gem.summary     = PKG_SUMMARY
	gem.description = <<-EOD
	#{PKG_SUMMARY}. And it needs more description.
	EOD

	gem.authors  	= "Michael Granger, Martin Chase, Dave McCorkhill, Jeremiah Jordan"
	gem.homepage 	= "http://deveiate.org/projects/Arrow"
	gem.rubyforge_project = 'arrow'

	gem.has_rdoc 	= true

	gem.files      	= RELEASE_FILES
	gem.test_files 	= SPEC_FILES + TEST_FILES

	gem.requirements << "mod_ruby >= 1.2.6"

  	gem.add_dependency( 'ruby-cache', '>= 0.3.0' )
  	gem.add_dependency( 'formvalidator', '>= 0.1.3' )
  	gem.add_dependency( 'pluginfactory', '>= 1.0.2' )

	gem.autorequire	= 'arrow'
end

Rake::GemPackageTask.new( gemspec ) do |task|
	task.gem_spec = gemspec
	task.need_tar = true
	task.need_zip = true
end

task :install => [:spec, :package] do
	installer = Gem::Installer.new( %{pkg/#{PKG_FILE_NAME}.gem} )
	installer.install
end

task :uninstall => [:clean] do
	uninstaller = Gem::Uninstaller.new( PKG_FILE_NAME )
	uninstaller.uninstall
end


