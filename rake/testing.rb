# 
# Rake tasklib for testing tasks
# $Id$
# 
# Authors:
# * Michael Granger <ged@FaerieMUD.org>
# 


### Test::Unit tests
begin
	gem 'flexmock', '>= 0.8.0'
	require 'rake/testtask'
	
	### Task: test
	### This will eventually go away when all the Test::Unit tests are replaced by
	### RSpec specifications.
	Rake::TestTask.new do |task|
	    task.libs << "test/lib"
	    task.test_files = TEST_FILES
	    task.verbose = true
	end

rescue LoadError => err
	task :no_test do
		$stderr.puts "Testing tasks not defined: %s" % [ err.message ]
	end
	
	task :test => :no_test
end


### RSpec specifications
begin
	gem 'rspec', '>= 1.1.3'
	require 'spec/rake/spectask'

	COMMON_SPEC_OPTS = ['-c', '-f', 's']

	### Task: spec
	Spec::Rake::SpecTask.new( :spec ) do |task|
		task.spec_files = SPEC_FILES
		task.libs += [LIBDIR]
		task.spec_opts = COMMON_SPEC_OPTS
	end


	namespace :spec do
		desc "Run rspec every time there's a change to one of the files"
        task :autotest do
            require 'autotest/rspec'

            autotester = Autotest::Rspec.new
			autotester.exceptions = %r{\.svn|\.skel}
            autotester.run
        end

	
		desc "Generate quiet output"
		Spec::Rake::SpecTask.new( :quiet ) do |task|
			task.spec_files = SPEC_FILES
			task.spec_opts = ['-f', 'p', '-D']
		end
	
		desc "Generate HTML output for a spec run"
		Spec::Rake::SpecTask.new( :html ) do |task|
			task.spec_files = SPEC_FILES
			task.spec_opts = ['-f','h', '-D']
		end

		desc "Generate plain-text output for a CruiseControl.rb build"
		Spec::Rake::SpecTask.new( :text ) do |task|
			task.spec_files = SPEC_FILES
			task.spec_opts = ['-f','p']
		end
	end
rescue LoadError => err
	task :no_rspec do
		$stderr.puts "Specification tasks not defined: %s" % [ err.message ]
	end
	
	task :spec => :no_rspec
	namespace :spec do
		task :autotest => :no_rspec
		task :quiet => :no_rspec
		task :html => :no_rspec
		task :text => :no_rspec
	end
end


begin
	namespace :coverage do
		gem 'rspec', '>= 1.1.3'
		gem 'rcov', '>= 0.8.1.2.0'

		require 'spec/rake/spectask'
		require 'spec/rake/verify_rcov'
		require 'rcov/rcovtask'
	
		### Task: rcov
		desc "Build RSpec test coverage reports"
		Spec::Rake::SpecTask.new( :spec ) do |task|
			task.spec_files = SPEC_FILES
			task.rcov_opts = ['--exclude', 'spec', '--aggregate', 'coverage.data']
			task.rcov = true
			task.rcov_dir = 'coverage'
		end

		desc "Build Test::Unit test coverage reports"
		Rcov::RcovTask.new( :test ) do |task|
			task.test_files = TEST_FILES
			task.rcov_opts = ['--exclude', 'spec', '--aggregate', 'coverage.data']
			task.output_dir = 'coverage'
		end

		task :clobber => ['clobber_spec', 'clobber_test']

		desc "Build coverage statistics"
		RCov::VerifyTask.new( :verify => [:spec, :test] ) do |task|
			task.threshold = 85.0
			task.require_exact_threshold = false
		end
	end
	
	task :coverage => [ 'coverage:clobber', 'coverage:spec', 'coverage:test' ]

rescue LoadError => err
	task :no_coverage do
		$stderr.puts "Coverage tasks not defined: %s" %
			[ err.message ]
	end
	
	task :coverage => :no_rspec
	namespace :coverage do
		task :spec => :no_coverage
		task :test => :no_coverage
		task :clobber => :no_coverage
	end
end
