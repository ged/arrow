#!/usr/bin/env ruby

require 'stringio'
require 'arrow/logger'
require 'arrow/logger/outputter'

# The Arrow::Logger::FileOutputter class, a derivative of
# Apache::Logger::Outputter. This is an outputter that writes to a
# file or other filehandle.
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
# Please see the file LICENSE in the top-level directory for licensing details.
#
class Arrow::Logger::FileOutputter < Arrow::Logger::Outputter

	# The default description
	DEFAULT_DESCRIPTION = "File Outputter"

	# The default format (copied from the superclass)
	DEFAULT_FORMAT = Arrow::Logger::Outputter::DEFAULT_FORMAT


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Logger::FileOutputter object. The +io+ argument
	### can be an IO or StringIO object, in which case output is sent to it
	### directly, a String, in which case it is used as the first argument
	### to File.open, or an Integer file descriptor, in which case a new IO
	### object is created which appends to the file handle matching that
	### descriptor.
	def initialize( uri, description=DEFAULT_DESCRIPTION, format=DEFAULT_FORMAT )
		if uri.hierarchical?
			@io = File.open( uri.path, File::WRONLY|File::CREAT )
		else
			case uri.opaque
			when /(std|def)err/i
				@io = $stderr
			when /(std|def)out/i
				@io = $defout
			when /^(\d+)$/
				@io = IO.for_fd( Integer($1), "w" )
			else
				raise "Unrecognized log URI '#{uri}'"
			end
		end

		super
	end


	######
	public
	######

	# The filehandle open to the logfile
	attr_accessor :io


	### Write the given +level+, +name+, +frame+, and +msg+ to the logfile.
	def write( time, level, name, frame, msg )
		if block_given?
			super
		else
			super {|msg| @io.puts(msg) }
		end
	end


	#########
	protected
	#########

	### Returns a String which should be included in the implementation-specific part 
	### of the object's inspection String.
	def inspection_details
		io_desc = 
			case @io
			when $stderr
				'STDERR'
			when $stdout
				'STDOUT'
			when StringIO
				'(StringIO 0x%0x)' % [ @io.object_id * 2 ]
			else
				'(IO: fd %d)' % [ @io.fileno ]
			end

		return [ super, io_desc ].join(', ')
	end

end # class Arrow::Logger::FileOutputter
