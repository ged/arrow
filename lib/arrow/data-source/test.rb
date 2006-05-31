#!/usr/bin/ruby
# 
# This file contains the Arrow::TestDataSource class, a derivative of
# Arrow::DataSource. Instances of this class are mock objects which encapsulate
# a snapshot of another data source object at a particular moment in time. It's
# intended to be used mostly for testing.
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



### Locally-stored mock data source class to be used for testing purposes.
class Arrow::TestDataSource < Arrow::DataSource

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$



	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################
	private_class_method :new


	### The identifier string for the data being copied.
	@real_source
	class << self
		attr_reader :real_source
	end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Creates a new TestData object with the given identifier, and
	### either loads the pre-existing data from disk, or creates it.
	def initialize( uri, source )
		@source = source + "/" + name
	end


	######
	public
	######

	### Saves the test data to the data directory.
	def save 
		name = File.join(TestData.data_path,@source)
		File.new(name, "w") {|file|
			file.write(@data.to_yaml)
		}
	end

end # class Arrow::TestDataSource

