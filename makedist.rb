#!/usr/bin/ruby
#
#	Distribution Maker Script
#	$Id: makedist.rb,v 1.2 2004/01/20 07:56:20 deveiant Exp $
#
#	Copyright (c) 2001, 2002, 2004, The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

require 'getoptlong'
require 'ftools'
require "./utils.rb"

include UtilityFunctions


### Configuration stuff

Options = [
	[ "--snapshot",	"-s",		GetoptLong::NO_ARGUMENT ],
	[ "--verbose",  "-v",		GetoptLong::NO_ARGUMENT ],
]

### End of configuration

# SVN Revision
SVNRev = %q$Rev$

# SVN Id
SVNId = %q$Id$

# SVN URL
SVNURL = %q$URL$

$Programs = {
	'tar'	=> nil,
	'rm'	=> nil,
	'zip'	=> nil,
	'cvs'	=> nil,
}

Distros = [

	# Tar+gzipped
	{
		'type'		=> 'Tar+Gzipped',
		'makeProc'	=> Proc.new {|distName|
			gzArchiveName = "%s.tar.gz" % distName
			if FileTest.exists?( gzArchiveName )
				message "Removing old archive #{gzArchiveName}..."
				File.delete( gzArchiveName )
			end
			system( $Programs['tar'], '-czf', gzArchiveName, distName ) or abort( "tar+gzip failed: #{$?}" )
		}
	},

	# Tar+bzipped
	{
		'type'		=> 'Tar+Bzipped',
		'makeProc'	=> Proc.new {|distName|
			bzArchiveName = "%s.tar.bz2" % distName
			if FileTest.exists?( bzArchiveName )
				message "Removing old archive #{bzArchiveName}..."
				File.delete( bzArchiveName )
			end
			system( $Programs['tar'], '-cjf', bzArchiveName, distName ) or abort( "tar failed: #{$?}" )
		}
	},

	# Zipped
	{
		'type'		=> 'Zipped',
		'makeProc'	=> Proc.new {|distName|
			zipArchiveName = "%s.zip" % distName
			if FileTest.exists?( zipArchiveName )
				message "Removing old archive #{zipArchiveName}..."
				File.delete( zipArchiveName )
			end
			system( $Programs['zip'], '-lrq9', zipArchiveName, distName ) or abort( "zip failed: #{$?}" )
		}
	},
]


# Set interrupt handler to restore tty before exiting
stty_save = `stty -g`.chomp
trap("INT") { system "stty", stty_save; exit }

### Main function
def main
	filelist = []
	snapshot = false

	# Read command-line options
	opts = GetoptLong::new( *Options )
	opts.each do |opt, arg|
		case opt

		when '--snapshot'
			snapshot = true

		when '--verbose'
			$VERBOSE = true

		else
			abort( "No such option '#{opt}'" )
		end
			
	end

	# Find the project name
	project = File::read( "CVS/Repository" ).chomp.sub( %r{.*/}, '' )
	header "%s Distribution Maker" % project

	# Look for programs to use
	message "Finding necessary programs...\n\n"
	for prog in $Programs.keys
		$Programs[ prog ] = findProgram( prog ) or
			abort "Required program #{prog} not found."
		message( "  #{prog}: %s\n" % $Programs[prog] )
	end
	message( "All required programs found.\n" )

	# Fetch the MANIFEST
	filelist = getVettedManifest()

	# Prompt for version/snapshot date
	version = distName = nil
	if snapshot
		version = promptWithDefault( "Snapshot version", Time::now.strftime('%Y%m%d') )
		distName = "%s-%s" % [ project, version ]
		tag = "SNAPSHOT_%s" % version
	else
		releaseVersion = extractNextVersionFromTags( filelist[0] )
		version = promptWithDefault( "Distribution version", releaseVersion )
		distName = "%s-%s" % [ project, version ]
		tag = "RELEASE_%s" % sprintf('%0.2f', version).gsub(/\./, '_') 
	end

	# Tag if desired
	tagFlag = promptWithDefault( "Tag '%s' with %s" % [ project, tag ], 'y' )
	if tagFlag =~ /^y/i
		$stderr.puts "Running #{$Programs['cvs']} -q tag #{tag}"
		system $Programs['cvs'], '-q', 'tag', tag
	end

	# Make the distdir
	message "Making distribution directory #{distName}..."
	Dir.mkdir( distName ) unless FileTest.directory?( distName )
	for file in filelist
		File.makedirs( File.dirname(File.join(distName,file)) )
		File.link( file, File.join(distName,file) )
	end

	# Make an archive file for each known kind
	for distro in Distros
		message "Making #{distro['type']} distribution..."
		distro['makeProc'].call( distName )
		message "done.\n"
	end

	# Remove the distdir
	if $Programs['rm']
		message "removing dist build directory..."
		system( $Programs['rm'], '-rf', distName )
		message "done.\n\n"
	else
		message "Cannot clean dist build directory: no 'rm' program was found."
	end
end

main	



