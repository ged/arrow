#!/usr/bin/ruby
# 
# Adds a class method 'which' to the 'File' class that behaves like the
# like-named *NIX command.
# 
# == Synopsis
# 
#   require 'filewhich'
#
#	httpd = File::which('httpd')
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
#
# Copyright (c) 2003 The FaerieMUD Consortium. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# == Version
#
#  $Id: filewhich.rb,v 1.2 2003/08/28 14:07:49 deveiant Exp $
# 

class File
	Win32Exts = %w{.exe .com .bat}

	def self::which( prog, path=ENV['PATH'] )
		path.split(File::PATH_SEPARATOR).each {|dir|
			# If running under Windows, look for prog + extensions
			if File::ALT_SEPARATOR
				ext = Win32Exts.find_all {|ext|
					f = File::join(dir, prog+ext)
					File::executable?(f) && !File::directory?(f)
				}
				ext.each {|f|
					f = File::join( dir, prog + f ).gsub(%r:/:,'\\')
					if block_given? then yield( f ) else return f end
				}
			else
				f = File::join( dir, prog )
				if File::executable?( f ) && ! File::directory?( f )
					if block_given? then yield(f) else return f end
				end
			end
		}

		return nil
	end
end 


