#!/usr/bin/env ruby
# 
# This file contains the Arrow::Wiki class, a small collection of data classes
# used by the demo Arrow wiki application.
# 
# == Subversion ID
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the BASE directory for licensing details.
#

require 'tableadapter'
require 'bluecloth'

### The class namespace.
module ArrowWiki

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	### Abstract base data class for wiki objects.
	class WikiDataObject < TableAdapter
		adapter_dsn 'dbi:Mysql:arrowwiki'
		adapter_username 'arrowwiki'
		adapter_password '<<==wiki'
	end


	### The top-level Wiki datastructure.
	class Wiki < WikiDataObject

		adapter_table 'wiki'
		adapter_sql :Mysql => %q{
			DROP TABLE IF EXISTS wiki;
			CREATE TABLE wiki (
				id			SMALLINT		UNSIGNED PRIMARY KEY auto_increment,
				name		VARCHAR(255)	NOT NULL,
				modtime		TIMESTAMP(14)
			) TYPE=InnoDB;
		}

		adapter_has_many :topics, :Topic, :wiki
		
	end # class Wiki


	### Topics (pages) in a Wiki.
	class Topic < WikiDataObject

		adapter_table 'topic'
		adapter_sql :Mysql => %q{
			DROP TABLE IF EXISTS topic;
			CREATE TABLE topic (
				id			INTEGER			UNSIGNED PRIMARY KEY auto_increment,
				wiki		SMALLINT		UNSIGNED NOT NULL
					REFERENCES wiki(id)
					ON UPDATE CASCADE ON DELETE RESTRICT,
				name		VARCHAR(255)	NOT NULL,
				content		TEXT,
				creator		INTEGER			UNSIGNED NOT NULL
					REFERENCES author(id)
					ON UPDATE CASCADE ON DELETE RESTRICT
			) TYPE=InnoDB;
		}

		adapter_has_one :wiki, :Wiki


		### Return the content as an HTML fragment
		def to_html
			BlueCloth.new( @content ).to_html
		end
	end


	### Participants in one or more Wikis.
	class Author < WikiDataObject

		adapter_table 'author'
		adapter_sql :Mysql => %q{
			DROP TABLE IF EXISTS author;
			CREATE TABLE author (
				id				INTEGER			UNSIGNED PRIMARY KEY auto_increment,
				name			VARCHAR(255)	NOT NULL,
				email_address	VARCHAR(255)	NOT NULL DEFAULT ''
			) TYPE=InnoDB;
		}

		adapter_has_many :topics, :Topic, :creator
		adapter_has_many :changes, :Delta, :author

	end


	### Delta or difference between different versions of a Topic.
	class Delta < WikiDataObject

		adapter_table 'delta'
		adapter_sql :Mysql => %q{
			DROP TABLE IF EXISTS delta;
			CREATE TABLE delta (
				id				INTEGER			UNSIGNED PRIMARY KEY auto_increment,
				topic			INTEGER			UNSIGNED NOT NULL
					REFERENCES topic(id)
					ON UPDATE CASCADE ON DELETE CASCADE,
				author			INTEGER			UNSIGNED NOT NULL
					REFERENCES author(id)
					ON UPDATE CASCADE ON DELETE RESTRICT,
				date			DATETIME(14)	NOT NULL DEFAULT '0000-00-00 00:00:00',
				changes			TEXT
			) TYPE=InnoDB;
		}

		adapter_has_one :author, :Author

	end


end # module ArrowWiki

