#!/usr/bin/ruby
#
#	Linguistics Module Install Script
#	$Id: install.rb,v 1.4 2004/03/14 01:47:23 stillflame Exp $
#
#	Thanks to Masatoshi SEKI for ideas found in his install.rb.
#
#	Copyright (c) 2001-2004 The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

require './utils.rb'
include UtilityFunctions

require 'rbconfig'
include Config

require 'find'
require 'ftools'


$version	= %q$Revision: 1.4 $
$rcsId		= %q$Id: install.rb,v 1.4 2004/03/14 01:47:23 stillflame Exp $

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
		'http://www.devEiate.org/code/PluginFactory-0.01.tar.gz'
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
				File::mkpath( dir, $verbose )
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

if $0 == __FILE__
	header "Arrow Installer #$version"

	for lib in RequiredLibraries
		testForRequiredLibrary( *lib )
	end

	viewOnly = ARGV.include? '-n'
	verbose = ARGV.include? '-v'

	debugMsg "Sitelibdir = '#{CONFIG['sitelibdir']}'"
	sitelibdir = CONFIG['sitelibdir']
	debugMsg "Sitearchdir = '#{CONFIG['sitearchdir']}'"
	sitearchdir = CONFIG['sitearchdir']

	message "Installing..."
	i = Installer.new( viewOnly )
	#i.installFiles( "redist", sitelibdir, 0444, verbose )
	i.installFiles( "lib", sitelibdir, 0444, verbose )

	message "done.\n"
end
	



