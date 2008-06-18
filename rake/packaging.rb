# 
# Rake tasklib for packaging tasks
# $Id$
# 
# Authors:
# * Michael Granger <ged@FaerieMUD.org>
# 

begin

	begin
		oldverbose = $VERBOSE
		$VERBOSE = false
		require 'rake/packagetask'
		require 'rake/gempackagetask'
		require 'rubygems/specification'
		require 'rubygems/remote_installer'
		require 'rubygems/doc_manager'
	ensure
		$VERBOSE = oldverbose
	end


	### Task: gem
	Rake::GemPackageTask.new( GEMSPEC ) do |task|
		task.gem_spec = GEMSPEC
		task.need_tar = true
		task.need_zip = true
	end


	require 'rubygems/dependency_installer'
	require 'rubygems/source_index'
	require 'rubygems/requirement'
	require 'rubygems/doc_manager'

	### Install the specified +gems+ if they aren't already installed.
	def install_gems( *gems )
		gems.flatten!

		defaults = Gem::DependencyInstaller::DEFAULT_OPTIONS.merge({
			:generate_rdoc     => true,
			:generate_ri       => true,
			:install_dir       => Gem.dir,
			:format_executable => false,
			:test              => false,
			:version           => Gem::Requirement.default,
		  })

		# Check for root
		if Process.euid != 0
			$stderr.puts "This probably won't work, as you aren't root, but I'll try anyway"
		end

		gemindex = Gem::SourceIndex.from_installed_gems

		gems.each do |gemname|
			if (( specs = gemindex.search(gemname) )) && ! specs.empty?
				log "Version %s of %s is already installed; skipping..." % 
					[ specs.first.version, specs.first.name ]
				next
			end

			rgv = Gem::Version.new( Gem::RubyGemsVersion )
			installer = nil

			log "Trying to install #{gemname.inspect}..."
			if rgv >= Gem::Version.new( '1.1.1' )
				installer = Gem::DependencyInstaller.new
				installer.install( gemname )
			else
				installer = Gem::DependencyInstaller.new( gemname )
				installer.install
			end

			installer.installed_gems.each do |spec|
				log "Installed: %s" % [ spec.full_name ]
			end

		end
	end


	### Task: install gems for development tasks
	DEPENDENCIES = %w[rspec rcov RedCloth ultraviolet tidy formvalidator ruby-cache flexmock 
		meta_project diff-lcs]
	desc "Install all dependencies"
	task :install_dependencies do
		install_gems( DEPENDENCIES )
	end


rescue LoadError => err
	task :no_packaging do
		$stderr.puts "Packaging tasks not defined: %s" % [ err.message ]
	end
	
	task :package       => :no_packaging
	task :gem           => :no_packaging
	task :install_gem   => :no_packaging
	task :uninstall_gem => :no_packaging
end

