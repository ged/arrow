#!/usr/bin/ruby
# 
# This file contains the Arrow::Config::YamlLoader class, a derivative of
# Arrow::Config::Loader. It is used to load configuration files written in YAML
# for the Arrow web application framework.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'yaml'

require 'arrow'
require 'arrow/config'
require 'arrow/utils'

module Arrow
class Config

	### It is used to load configuration files written in YAML for the Arrow web
	### application framework.
	class YamlLoader < Arrow::Config::Loader

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$

		# Add YAML domain types for Arrow classes

		YAML::add_domain_type( Arrow::YamlDomain, "arrowPath" ) {|type, val|
			obj = nil
			case val
			when Array
				Arrow::Logger.debug "Adding %p to loaded Arrow::Path" % [ val ]
				obj = Arrow::Path::new( val )
			else
				raise "Invalid #{type}: %p" % val
			end

			obj
		} 



		######
		public
		######

		### Load and return configuration values from the YAML +file+
		### specified.
		def load( filename )
			self.log.info "Loading YAML-format configuration from '%s'" % filename
			return YAML::load( File::read(filename) )
		end


		### Save configuration values to the YAML +file+ specified.
		def save( confighash, filename )
			self.log.info "Saving YAML-format configuration to '%s'" % filename
			File::open( filename, File::WRONLY|File::CREAT|File::TRUNC ) {|ofh|
				ofh.print( confighash.to_yaml )
			}
		end


		### Return +true+ if the specified +file+ is newer than the given
		### +time+.
		def isNewer?( file, time )
			return false unless File::exists?( file )
			st = File::stat( file )
			self.log.debug "File mtime is: %s, comparison time is: %s" %
				[ st.mtime, time ]
			return st.mtime > time
		end


	end # class YamlLoader

end # class Config
end # module Arrow


