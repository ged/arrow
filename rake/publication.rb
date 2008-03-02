# 
# Rake tasklib for testing tasks
# $Id$
# 
# Authors:
# * Michael Granger <ged@FaerieMUD.org>
# 


PROJECT_HOST = 'deveiate.org'
PROJECT_HTMLDIR = "/usr/local/trac/Arrow/htdocs/api"

### Publication tasks
begin
	gem 'meta_project'

	require 'meta_project'
	require 'rake/contrib/sshpublisher'
	require 'rake/contrib/xforge'
	require 'rake/contrib/sshpublisher'

	task :release => [:changelog, :release_files, :publish_doc, :publish_news, :tag]

	task :verify_env_vars do
		raise "RUBYFORGE_USER environment variable not set!" unless ENV['RUBYFORGE_USER']
		raise "RUBYFORGE_PASSWORD environment variable not set!" unless ENV['RUBYFORGE_PASSWORD']
	end

	# Publish everything in the api docs directory to the project page
	desc "Publish manual and API docs to the project site"
	task :publish_docs => [ :rdoc, :manual ] do
		publisher = Rake::SshDirPublisher.new( "deveiate.org", PROJECT_HTMLDIR, APIDOCSDIR )
		publisher.upload
	end


	desc "Release files on RubyForge"
	task :release_files => [:gem] do
		release_files = FileList[ "pkg/#{PKG_FILE_NAME}.*" ]

		Rake::XForge::Release.new(MetaProject::Project::XForge::RubyForge.new('deveiate')) do |release|
			release.user_name    = ENV['RUBYFORGE_USER']
			release.password     = ENV['RUBYFORGE_PASSWORD']
			release.files        = release_files.to_a
			release.release_name = "#{PKG_NAME} #{PKG_VERSION}"
			release.changes_file = 'ChangeLog'
			# The rest of the options are defaults (among others, release_notes and
			# release_changes, parsed from CHANGES)
		end
	end


	desc "Publish news on RubyForge"
	task :publish_news => [:gem] do
		release_files = FileList[
			"pkg/#{PKG_FILE_NAME}.gem"
		]

		Rake::XForge::NewsPublisher.new(MetaProject::Project::XForge::RubyForge.new('xforge')) do |news|
			news.user_name = ENV['RUBYFORGE_USER']
			news.password = ENV['RUBYFORGE_PASSWORD']
		end
	end

rescue LoadError => err
	task :no_meta_project do
		$stderr.puts "Release tasks not defined: MetaProject/XForge tasklib not available: %s" %
			[ err.message ]
	end

	task :release => :no_meta_project
end


