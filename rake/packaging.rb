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

		gem.files      	= RELEASE_FILES
		gem.test_files 	= SPEC_FILES + TEST_FILES

		gem.requirements << "mod_ruby >= 1.2.6"

	  	gem.add_dependency( 'ruby-cache', '>= 0.3.0' )
	  	gem.add_dependency( 'formvalidator', '>= 0.1.3' )
	  	gem.add_dependency( 'pluginfactory', '>= 1.0.2' )
	end


	### Task: gem
	Rake::GemPackageTask.new( GEMSPEC ) do |task|
		task.gem_spec = GEMSPEC
		task.need_tar = true
		task.need_zip = true
	end


	class Gem::RemoteInstaller

		def install( gem_name, version_requirement=Gem::Requirement.default, force=false, install_dir=Gem.dir )
			unless version_requirement.respond_to?(:satisfied_by?)
				version_requirement = Gem::Requirement.new [version_requirement]
			end
			installed_gems = []
			begin
				spec, source = find_gem_to_install(gem_name, version_requirement)
				dependencies = find_dependencies_not_installed(spec.dependencies)

				installed_gems << install_dependencies(dependencies, force, install_dir)

				cache_dir = @options[:cache_dir] || File.join(install_dir, "cache")
				destination_file = File.join( cache_dir, spec.full_name + ".gem" )

				download_gem( destination_file, source, spec )

				installer = new_installer( destination_file )
				installed_gems.unshift( installer.install )
			rescue Gem::RemoteInstallationSkipped => e
				alert_error e.message
			end
			return installed_gems.flatten
		end

	end

	### Attempt to install the given +gemlist+.
	def install_gems( gemlist )
		# Check for root
		unless Process.euid.zero?
			$stderr.puts "This probably won't work, as you aren't root, but I'll try anyway"
		end

		installer = Gem::RemoteInstaller.new( :include_dependencies => true )
		gemindex = Gem::SourceIndex.from_installed_gems

		gemlist.each do |gemname|
			if (( specs = gemindex.search(gemname) )) && ! specs.empty?
				$stderr.puts "Version %s of %s is already installed; skipping..." % 
					[ specs.first.version, specs.first.name ]
				next
			end

			$stderr.puts "Trying to install #{gemname}..."
			gems = installer.install( gemname )
			gems.compact!
			$stderr.puts "Installed: %s" % [gems.collect {|spec| spec.full_name}.join(', ')]

			gems.each do |gem|
				Gem::DocManager.new( gem, '-w4 -SNH' ).generate_ri
				Gem::DocManager.new( gem, '-w4 -SNH' ).generate_rdoc
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

