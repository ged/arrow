#!/usr/bin/ruby
#
#	Module Install Script
#	$Id$
#
#	Thanks to Masatoshi SEKI for ideas found in his install.rb.
#
#	Copyright (c) 2001-2004 The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

BEGIN {
	$basedir = File::dirname( File::expand_path(__FILE__) )
	$LOAD_PATH.unshift( "#$basedir/lib" )
	
	require "#$basedir/utils.rb"
	require 'rbconfig'
	require 'find'
	require 'ftools'
	require 'optparse'
}

include UtilityFunctions
include Config

$version	= %q$Revision: 1.4 $
$rcsId		= %q$Id$

# Define required libraries
RequiredLibraries = [
	# libraryname, nice name, RAA URL, Download URL
	[ 'cache', "Ruby-Cache", 
		'http://www.ruby-lang.org/en/raa-list.rhtml?name=Ruby-Cache',
		'redist/ruby-cache-0.3.tar.gz',
	],
	[ 'formvalidator', "FormValidator", 
		'http://www.ruby-lang.org/en/raa-list.rhtml?name=formvalidator',
		'redist/formvalidator-0.1.3.tar.gz',
	],
	[ 'pluginfactory', "PluginFactory", 
		'http://raa.ruby-lang.org/list.rhtml?name=pluginfactory',
		'redist/PluginFactory-1.0.0.tar.gz'
	],
	[ 'hashslice', "HashSlice", 
		'http://www.ruby-lang.org/en/raa-list.rhtml?name=hashslice',
		'redist/hashslice.rb',
	],
	[ 'strscan', "Strscan", 
		'http://www.ruby-lang.org/en/raa-list.rhtml?name=strscan',
		'http://i.loveruby.net/archive/strscan/strscan-0.6.7.tar.gz',
	],
]

class Installer

	@@PrunePatterns = [
		/CVS/,
		/~$/,
		%r:(^|/)\.:,
		/\.tpl$/,
	]

	def initialize( testing=false )
		@ftools = (testing) ? self : File
	end

	### Make the specified dirs (which can be a String or an Array of Strings)
	### with the specified mode.
	def makedirs( dirs, mode=0755, verbose=false )
		dirs = [ dirs ] unless dirs.is_a? Array

		oldumask = File::umask
		File::umask( 0777 - mode )

		for dir in dirs
			if @ftools == File
				File::mkpath( dir, verbose )
			else
				$stderr.puts "Make path %s with mode %o" % [ dir, mode ]
			end
		end

		File::umask( oldumask )
	end

	def install( srcfile, dstfile, mode=nil, verbose=false )
		dstfile = File.catname(srcfile, dstfile)
		unless FileTest.exist? dstfile and File.cmp srcfile, dstfile
			$stderr.puts "   install #{srcfile} -> #{dstfile}"
		else
			$stderr.puts "   skipping #{dstfile}: unchanged"
		end
	end

	public

	def installFiles( src, dstDir, mode=0444, verbose=false )
		directories = []
		files = []
		
		if File.directory?( src )
			Find.find( src ) {|f|
				Find.prune if @@PrunePatterns.find {|pat| f =~ pat}
				next if f == src

				if FileTest.directory?( f )
					directories << f.gsub( /^#{src}#{File::Separator}/, '' )
					next 

				elsif FileTest.file?( f )
					files << f.gsub( /^#{src}#{File::Separator}/, '' )

				else
					Find.prune
				end
			}
		else
			files << File.basename( src )
			src = File.dirname( src )
		end
		
		dirs = [ dstDir ]
		dirs |= directories.collect {|d| File.join(dstDir,d)}
		makedirs( dirs, 0755, verbose )
		files.each {|f|
			srcfile = File.join(src,f)
			dstfile = File.dirname(File.join( dstDir,f ))

			if verbose
				if mode
					$stderr.puts "Install #{srcfile} -> #{dstfile} (mode %o)" % mode
				else
					$stderr.puts "Install #{srcfile} -> #{dstfile}"
				end
			end

			@ftools.install( srcfile, dstfile, mode, verbose )
		}
	end

end

HttpdConfSection = <<EOF
RubyRequire arrow

<Location /arrow-demo>
	SetHandler ruby-object
	RubyHandler "Arrow::Dispatcher::instance( '%s' )"
</Location>
EOF

if $0 == __FILE__
	header "Arrow Installer #$version"

	for lib in RequiredLibraries
		testForRequiredLibrary( *lib )
	end

	require 'arrow/config'
	dryrun = false

	# Parse command-line switches
	ARGV.options {|oparser|
		oparser.banner = "Usage: #$0 [options]\n"

		oparser.on( "--verbose", "-v", TrueClass, "Make progress verbose" ) {
			$VERBOSE = true
			debugMsg "Turned verbose on."
		}

		oparser.on( "--dry-run", "-n", TrueClass, "Don't really install anything" ) {
			debugMsg "Turned dry-run on."
			dryrun = true
		}

		# Handle the 'help' option
		oparser.on( "--help", "-h", "Display this text." ) {
			$stderr.puts oparser
			exit!(0)
		}

		oparser.parse!
	}

	debugMsg "Sitelibdir = '#{CONFIG['sitelibdir']}'"
	sitelibdir = CONFIG['sitelibdir']
	debugMsg "Sitearchdir = '#{CONFIG['sitearchdir']}'"
	sitearchdir = CONFIG['sitearchdir']

	message "Installing Arrow libraries..."
	i = Installer.new( dryrun )
	#i.installFiles( "redist", sitelibdir, 0444, verbose )
	i.installFiles( "lib", sitelibdir, 0444, $VERBOSE )
	message "done.\n\n"

	# Ask if the demo applets should be installed
	message "Arrow comes with some demonstration applets/templates.\n"
	ans = promptWithDefault( "Would you like to install them?", "y" )
	if /^y/i.match( ans )
		message "\nFirst the applet and template files. If you don't mind ",
			"keeping this source directory around, they can be loaded from ",
			"here. Otherwise, specify somewhere to copy them.\n"
		demodir = promptWithDefault( "Applet/template directory", $basedir )
		appletdir = templatedir = nil

		# If the files need to be copied, do so
		if demodir != $basedir
			message "Installing demo applets..."
			appletdir = File::join( demodir, "applets" )
			#File::mkpath( appletdir, $Verbose )
			i.installFiles( "applets", appletdir, 0644, $VERBOSE )
			message "done.\n"

			message "Installing demo templates..."
			templatedir = File::join( demodir, "templates" )
			#File::mkpath( templatedir, $Verbose )
			i.installFiles( "templates", templatedir, 0644, $VERBOSE )
			message "done.\n"
		else
			appletdir = File::join( $basedir, "applets" )
			templatedir = File::join( $basedir, "templates" )
		end

		# Load the demo config and correct the paths
		configfile = File::join( $basedir, "demo.cfg" )
		newconfig = File::join( demodir, "demo.cfg" )

		if File::exists?( newconfig )
			message "Not replacing existing config '%s'\n" % newconfig
		else
			config = Arrow::Config::load( configfile )
			config.applets.path.dirs = [ appletdir ]
			config.templates.path.dirs = [ templatedir ]

			message "Writing Arrow config file to '#{newconfig}'..."
			config.write( newconfig ) unless dryrun
			message "done.\n\n"
		end

		# Now show the user what they'll need to put in their httpd.conf.
		message "Okay, now all you should have to do is put something like ",
			"this in your httpd.conf and restart:\n\n"
		puts HttpdConfSection % newconfig
	else
		message "done.\n"
	end
	

end
	



