#!/usr/bin/ruby
# 
# This file contains the Arrow module, a namespace container for classes in the
# Arrow web application framework.
# 
# == Rcsid
#
#  $Id: arrow.rb,v 1.5 2003/11/09 19:49:24 deveiant Exp $
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

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.5 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: arrow.rb,v 1.5 2003/11/09 19:49:24 deveiant Exp $

	require 'arrow/exceptions'
	require 'arrow/mixins'
	require 'arrow/logger'
	require 'arrow/object'

	require 'arrow/broker'
	require 'arrow/dispatcher'
	require 'arrow/application'
	require 'arrow/datasource'
	require 'arrow/monitor'
	require 'arrow/template'
	require 'arrow/config'
	require 'arrow/session'

end # class Arrow


