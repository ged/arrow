#!/usr/bin/ruby
# 
# This file contains the visitor patterned criteria extension to the
# Arrow::DataSource class
# 
# == Rcsid
# 
# $Id: datasourcecriteria.rb,v 1.1 2004/02/29 02:58:21 stillflame Exp $
# 
# == Authors
# 
# * Martin Chase <stillflame@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#


raise LoadError.new( "Arrow::DataSource must first be loaded." ) unless
    Object.constants.include?("Arrow") and
    Arrow.constants.include?("DataSource")

require 'criteria'

### The visitor patterned criteria extension to the Arrow::DataSource class.
class Arrow::DataSource

    # CVS version tag
    CriteriaVersion = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

	# CVS id tag
	CriteriaRcsid = %q$Id: datasourcecriteria.rb,v 1.1 2004/02/29 02:58:21 stillflame Exp $


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

