#!/usr/bin/ruby
# 
# This file contains the Arrow::Subject class and a few default subject
# derivatives. Arrow::Subject is a base class for objects which are a single
# statistic or datapoint for the monitoring system in the Arrow Web Application
# Framework. Applications may attach themselves to monitors for specific
# classes, specific types of Subjects, or varying combinations of the two
# criteria.
# 
# == Synopsis
# 
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
# Please see the file docs/COPYRIGHT for licensing details.
#

require 'observer'

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/object'

### An abstract base class for monitor "subjects", which are datapoints
### which may be subscribed to by monitoring applications.
class Arrow::Subject < Arrow::Object
	include Observable

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$



	### Initialize a new Arrow::Subject (should be called from derivatives).
	def initialize( description ) # :notnew:
		@description = description
	end
	
end # class Arrow::Subject
