#!/usr/bin/ruby
# 
# Output logging messages in ANSI colors according to their level
# 
# == Synopsis
# 
#   
# 
# == Authors
# 
# * Michael Granger <mgranger@laika.com>
# 
# == Copyright
#
# Copyright (c) 2006 Laika, Inc
# 
# This work is proprietary source code, and may not be copied or transferred
# without permission.
# 
# == Version
#
#  $Id$
# 

require 'arrow/logger/fileoutputter'

### Output logging messages in ANSI colors according to their level
class Arrow::Logger::ColorOutputter < Arrow::Logger::FileOutputter

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Set some ANSI escape code constants (Shamelessly stolen from Perl's
	# Term::ANSIColor by Russ Allbery <rra@stanford.edu> and Zenin <zenin@best.com>
	AnsiAttributes = {
		'clear'      => 0,
		'reset'      => 0,
		'bold'       => 1,
		'dark'       => 2,
		'underline'  => 4,
		'underscore' => 4,
		'blink'      => 5,
		'reverse'    => 7,
		'concealed'  => 8,

		'black'      => 30,   'on_black'   => 40, 
		'red'        => 31,   'on_red'     => 41, 
		'green'      => 32,   'on_green'   => 42, 
		'yellow'     => 33,   'on_yellow'  => 43, 
		'blue'       => 34,   'on_blue'    => 44, 
		'magenta'    => 35,   'on_magenta' => 45, 
		'cyan'       => 36,   'on_cyan'    => 46, 
		'white'      => 37,   'on_white'   => 47
	}


	# Default color map: :level => %w{color scheme}
	DEFAULT_COLOR_SCHEME = {
		:debug		=> %w{dark white},
		:info		=> %w{cyan},
		:notice		=> %w{bold cyan},
		:warning	=> %w{bold yellow},
		:error		=> %w{bold red},
		:crit		=> %w{bold white on_red},
		:alert		=> %w{bold blink white on_red},
		:emerg		=> %w{bold blink yellow on_red},
	}


	### Override the default to add color scheme instance variable
	def initialize( uri, description=DefaultDescription, format=DefaultFormat ) # :notnew:
		super
		@color_scheme = DEFAULT_COLOR_SCHEME.dup
	end


	######
	public
	######

	# The color scheme hash for this logger
	attr_reader :color_scheme


	### Write the given +level+, +name+, +frame+, and +msg+ to the logfile.
	def write( time, level, name, frame, msg )
		colors = @color_scheme[level]
		super do |msg|
			color_msg = colorize( msg, colors )
			@io.puts( color_msg )
		end
	end


	#######
	private
	#######

	### Create a string that contains the ANSI codes specified and return it
	def ansi_code( *attributes )
		attr = attributes.flatten.collect {|a| AnsiAttributes[a] }.compact.join(';')
		if attr.empty? 
			return ''
		else
			return "\e[%sm" % attr
		end
	end


	### Colorize the given +string+ with the specified +attributes+ and return 
	### it, handling line-endings, etc.
	def colorize( string, *attributes )
		ending = string[/(\s)$/] || ''
		string = string.rstrip
		return ansi_code( *attributes ) + string + ansi_code( 'reset' ) + ending
	end

end # class Arrow::Logger::ColorOutputter
