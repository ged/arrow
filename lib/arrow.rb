#!/usr/bin/ruby
# 
# This file contains the Arrow module, a namespace container for classes in the
# Arrow web application framework.
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Martin Chase <mchase@rubycrafters.com>
# * Michael Granger <mgranger@rubycrafters.com>
# * David McCorkhill <dmccorkhill@rubycrafters.com>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#


### The module that serves as a namespace for all Arrow classes.
module Arrow

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	# Yaml stuff
	YamlDomain = "rubycrafters.com,2003-10-22"

	require 'arrow/exceptions'
	require 'arrow/mixins'
	require 'arrow/logger'
	require 'arrow/object'

	require 'arrow/broker'
	require 'arrow/dispatcher'
	require 'arrow/applet'
	require 'arrow/datasource'
	require 'arrow/monitor'
	require 'arrow/template'
	require 'arrow/config'
	require 'arrow/session'

end # class Arrow


