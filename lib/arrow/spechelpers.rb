#!/usr/bin/env ruby

require 'pathname'

require 'apache/fakerequest'

require 'arrow'
require 'arrow/applet'

# 
# A collection of helper methods and classes for RSpec applet specifications
# 
# == Synopsis
# 
#   require 'arrow/spechelpers'
#
#   describe "SomeApplet" do
#       include Arrow::AppletFixtures
#       
#       before( :all ) do
#           @appletclass = load_appletclass( "someapplet" )
#       end
#       
#       before( :each ) do
#           @applet = @appletclass.new( nil, nil, nil )
#       end
#   end
#   
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <mgranger@laika.com>
# 
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#
module Arrow::SpecHelpers

	TEST_HEADERS = {
		'Host'            => 'www.example.com:80',
		'User-Agent'      => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-US; rv:1.8.1.4) Gecko/20070515 Firefox/2.0.0.4',
		'Accept'          => 'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5',
		'Accept-Language' => 'en-us,en;q=0.5',
		'Accept-Encoding' => 'gzip,deflate',
		'Accept-Charset'  => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
		'Keep-Alive'      => '300',
		'Connection'      => 'keep-alive',
		'Referer'         => 'https://www.example.com/',
	}


	### Find directories that applets live in (current just searches the CWD for subdirectories
	### called 'applets')
	def find_applet_directories
		basedir = Pathname.pwd
		return Pathname.glob( basedir + '**' + 'applets' ).
			find_all {|path| path.directory? && path.readable? }
	end
	

	### Load an appletclass for the specified +name+ and return it.
	def load_appletclass( name )
		dirs = self.find_applet_directories
		appletfiles = dirs.collect {|dir| Pathname.glob(dir + "**/#{name}.rb") }.flatten

		if appletfiles.empty?
			raise "Couldn't find an applet named '#{name}' in applet path %s" %
				[ dirs.collect {|dir| dir.to_s}.join(':') ]
		end
		
		return Arrow::Applet.load( appletfiles.first ).first
	end

end # Arrow::SpecHelpers

