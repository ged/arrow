DROP TABLE test;
CREATE TABLE test (
	id			int(11)			NOT NULL auto_increment,
	bar			varchar(32)		NOT NULL default '',
	foo			varchar(32)		default '',
	created		timestamp(14)	NOT NULL,
	modified	timestamp(14)	NOT NULL,
	PRIMARY KEY (id)
) TYPE=MyISAM;

INSERT INTO test (bar,foo,created,modified) VALUES ("meow", "moo", NULL, NULL);