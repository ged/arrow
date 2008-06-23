#!/usr/bin/env ruby
# 
# This file contains the visitor patterned criteria extension to the
# Arrow::DataSource class
# 
# == Subversion Id
#
#  $Id$
# 
# == Authors
# 
# * Martin Chase <stillflame@FaerieMUD.org>
# 
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the BASE directory for licensing details.
#


raise LoadError.new( "Arrow::DataSource must first be loaded." ) unless
    Object.constants.include?("Arrow") and
    Arrow.constants.include?("DataSource")

require 'criteria'

### The visitor patterned criteria extension to the Arrow::DataSource class.
class Arrow::DataSource

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$



	######
	public
	######

    ### Returns whether the optional criteria extensions are loaded.
    def criteria?
        true
    end


    ### Return the criteria table for construction of a query.
    def criteria
        Table.new
    end

	#########
	protected
	#########


end # class DataSource

