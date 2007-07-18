#!/usr/bin/env ruby

require 'tmpdir'

def make_tmpname( prefix='testingfile' )
	return "%s/%s.%d" % [ Dir.tmpdir, prefix, Process.pid ]
end

