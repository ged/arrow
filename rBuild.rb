#!/usr/bin/env ruby
#
#	rBuild.rb - Build the Arrow framework.
#
# == Synopsis
#
#	$ ruby rBuild.rb -[options] [target, ...]
#
# == Rcsid
#
#	$Id: rBuild.rb,v 1.2 2003/12/02 07:03:25 deveiant Exp $
#

require "modulebuilder"

class ArrowBuilder < ModuleBuilder

	include ModuleBuilder::Ruby

	# Additional command-line options
	Options = [
		["--with-apxs=DIR", String, "Path to the Apache extension"],
	]

	# Project attributes
	project_attr :name, "arrow"
	project_attr :version, "0.01"
	project_attr :license, "CCL"
	project_attr :dependencies, []
	project_attr :short_description, "An Apache+mod_ruby web application framework"
	project_attr :description, <<-EOF.gsub( /^\t\t/, '' )
		Later.
	EOF
	project_attr :url, 'http://www.rubycrafters.com/projects/Arrow/'
	project_attr :download, 'http://www.rubycrafters.com/projects/Arrow/latest-snapshot.tar.gz'

end


if __FILE__ == $0
	ArrowBuilder::build
end
