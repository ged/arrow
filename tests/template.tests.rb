#!/usr/bin/ruby -w
#
# Unit test for the Arrow::Template class
# $Id: 05_template.tests.rb,v 1.11 2004/01/23 16:23:51 deveiant Exp $
#
# Copyright (c) 2003, 2004 RubyCrafters, LLC. Most rights reserved.
# 
# This work is licensed under the Creative Commons Attribution-ShareAlike
# License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/1.0/ or send a letter to Creative
# Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
#
# 

unless defined? Arrow::TestCase
	testsdir = File::dirname( File::expand_path(__FILE__) )
	basedir = File::dirname( testsdir )
	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/tests/lib" unless
		$LOAD_PATH.include?( "#{basedir}/tests/lib" )

	require 'arrowtestcase'
end

require 'arrow/template'

### Collection of tests for the Arrow::Template class.
class Arrow::TemplateTestCase < Arrow::TestCase

	WHITESPACE_OR_COMMENT = '(\s|<!--(?:[^-]|-(?!->))+-->)*'

	# The directory all test data files are located in
	TestDataDir = File::join( File::dirname(__FILE__), "data" )

	# The instance variables which should have underbarred accessors
	TemplateAttr = %w{
		attributes syntaxTree config renderers file source creationTime
	}


	### Build and return a Regexp to match the given +content+ in output that
	### only otherwise contains whitespace and HTML comments. If +content+ is
	### +nil+, match just whitespace and HTML comments.
	def templateContentRe( *content )
		parts = [ '\\A', WHITESPACE_OR_COMMENT ]
		content.each do |pat|
			case pat
			when Regexp
				parts << pat.to_s
			else
				parts << Regexp::quote( pat )
			end
			parts << WHITESPACE_OR_COMMENT
		end
		parts << '\\Z'

		return Regexp::new( parts.join('') )
	end


	### Read test data into a Hash for later
	TestTemplates = {}
	begin
		inTemplate = seenEnd = false;
		section, template, part = nil
		linenum = 0

		# Read this file, skipping lines until the __END__ token. Then start
		# reading the tests.
		File::foreach( __FILE__ ) {|line|
			linenum += 1
			if /^__END__/ =~ line then seenEnd = true; next end
			debugMsg "#{linenum}: #{line.chomp}"
			next unless seenEnd
			line.chomp!
			
			case line

			# Directive changes look like:
			# # Set directive
			when /^### (\w+) directive/i
				section = $1.downcase.intern
				TestTemplates[ section ] ||= {}

			# Subtests for current directive look like:
			# === Simple
			when /^===\s*(.+)/
				next unless section
				template = $1.downcase.gsub( /\s+(.)/ ) {|match| $1.upcase}.intern
				TestTemplates[section][template] = {
					:template => '',
					:code => '',
					:linenumber => linenum,
				}
				part = :template
				debugMsg "Found template '%s' for the '%s' section at line %d" %
					[ template.inspect, section.inspect, linenum ]
				TestTemplates[ section ][ template ][:template] = ''

			# Separator between template and test code looks like:
			# ---
			when /^---\s*$/
				part = :code

			# End of current subtest looks like:
			# ===
			when /^===\s*$/
				template = nil

			# Anything else is added to whatever's currently in scope, or
			# skipped if nothing's in scope.
			else
				next unless section && template
				TestTemplates[ section ][ template ][part] << line << "\n"
			end
		}

		### Generate methods for all of the test data
		counter = 50
		TestTemplates.each {|section, templates|
			templates.each {|templateName, content|
				methodName = "test_%03d_%s_%s" %
					[ counter, section, templateName ]
				debugMsg "Generating test method #{methodName}"

				# If there's no code with the template, then just expect a
				# failure in instantiation.
				if content[:code].empty?
					code =  %{
						def #{methodName}
							printTestHeader "Template: #{section} (#{templateName})"
							rval = nil
							source = <<-'TEMPLATE_END'.gsub(/^\t/, '')
							#{content[:template]}
							TEMPLATE_END

							assert_raises( Arrow::ParseError ) {
								template = Arrow::Template::new(source)
							}
						end
						}.gsub( /^\t{6}/, '' )
				else
					code =  %{
						def #{methodName}
							printTestHeader "Template: #{section} (#{templateName})"
							rval = template = nil
							source = <<-'TEMPLATE_END'.gsub(/^\t/, '')
							#{content[:template]}
							TEMPLATE_END

							assert_nothing_raised {
								template = Arrow::Template::new(source)
							}
							assert_instance_of Arrow::Template, template
							template._config[:debuggingComments] = true if $DEBUG

							# Make sure all the attr_underbarred_* methods work
							TemplateAttr.each do |ivar|
								assert_has_ivar ivar.intern, template
								assert_nothing_raised {
									rval = template.send( "_\#{ivar}".intern )
								}
								assert_ivar_equal rval, template, ivar.intern
							end

							# Test attribute hashish setting/getting
							assert_nothing_raised {
								rval = template._attributes['foo'] = 'bar'
							}
							assert_respond_to template, :[]
							assert_nothing_raised {
								rval = template['foo']
							}
							assert_equal 'bar', rval
							assert_respond_to template, :[]=
							assert_nothing_raised {
								template['foo'] = 'tinkywinky'
							}
							assert_nothing_raised {
								rval = template._attributes['foo']
							}
							assert_equal 'tinkywinky', rval

							# Test #changed? to make sure it doesn't error even
							# with templates not loaded from a file.
							assert_nothing_raised {
								rval = template.changed?
							}
							assert_equal false, rval

							#{content[:code]}
						end
						}.gsub( /^\t{6}/, '' )
				end

				debugMsg "Installing test method (line #{content[:linenumber]}): #{code}"
				eval( code, nil, __FILE__,
					  content[:linenumber] - code.count("\n") + content[:code].count("\n") )

				counter += 1
			}
		}
	end



	#################################################################
	###	T E S T S
	#################################################################

	### Instance test
	def test_00_Class
		printTestHeader "Template: Class"
		assert_instance_of Class, Arrow::Template
	end


	### Loadpath
	def test_01_LoadPath
		printTestHeader "Template: LoadPath"
		rval = nil

		assert_respond_to Arrow::Template, :loadPath
		assert_nothing_raised {
			Arrow::Template.loadPath << TestDataDir
		}
		assert_nothing_raised {
			rval = Arrow::Template.loadPath
		}

		assert_include TestDataDir, rval
	end
end


#####################################################################
###	T E S T   D A T A
#####################################################################
__END__

### Attribute directive
=== Simple

<?attr test?>

---
debugMsg "Testing getter"
assert_nothing_raised { rval = template.test }
assert_equal nil, rval

debugMsg "Testing setter"
assert_nothing_raised { template.test = "foo" }
assert_equal "foo", template.test

assert_nothing_raised {	rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('foo'), rval )
===

=== With format

<?attr '|%-15s|' % test?>

---
testdata = ("x" * 5)

assert_nothing_raised { template.test = testdata }
assert_equal testdata, template.test

assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe(/\|x{5}\s{10}\|/), rval )
===

=== Malformed1

<?attr?>

===


=== Malformed2

<?attr '%s' test ?>

===


### Call directive
=== Simple

<?call test?>

---
debugMsg "Testing getter"
assert_nothing_raised { rval = template.test }
assert_equal nil, rval

debugMsg "Testing setter"
assert_nothing_raised { template.test = "foo" }
assert_equal "foo", template.test

assert_nothing_raised {	rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('foo'), rval )
===



=== With format

<?call '|%-15s|' % test?>

---
testdata = ("x" * 5)

assert_nothing_raised { template.test = testdata }
assert_equal testdata, template.test

assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe(/\|x{5}\s{10}\|/), rval )
===



=== With format and additional quotes

<?call '|%-15s|' % test?>
'Some more "quoted" stuff to make sure the match doesn't grab them.

---
testdata = ("x" * 5)

assert_nothing_raised { template.test = testdata }
assert_equal testdata, template.test

assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe(/\|x{5}\s{10}\|.*them\./m), rval )
===


=== Malformed1

<?call?>

===


=== Malformed2

<?call "%s" tests ?>

===


=== IdSub Test

<?call test ? "test" : "no test"?>

---
assert_nothing_raised { template.test = true }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe(/^test/), rval )
===


### Set directive
=== Simple

<?set time = Time::now ?>

---
assert_nothing_raised { rval = template['time'] }

assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe(), rval )
===

=== Method Chain

<?set time = Time::now.strftime( "%Y%m%d %H:%M:%S" ) ?>

---
assert_nothing_raised { rval = template['time'] }
debugMsg "template['time'] => %p" % rval

assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe(), rval )
===

=== Rendered later

<?set val = "Passed."?>
<?attr val?>

---
assert_respond_to template, :val
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_not_match( /error/i, rval )
assert_match( templateContentRe("Passed."), rval )
===

### If directive
=== Simple

<?if test?>
Passed.
<?end?>

---
assert_nothing_raised { template.test = true }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('Passed.'), rval )
===

=== Simple with explicit end

<?if test?>
Passed.
<?end if?>

---
assert_nothing_raised { template.test = true }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('Passed.'), rval )
===

=== Simple with mismatched end

<?if test?>
Passed.
<?end for?>

---
assert_nothing_raised { template.test = true }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('Passed.'), rval )
===

=== With match

<?if test.match(/foo/) ?>
Passed.
<?end?>

---
assert_nothing_raised { template.test = "foo" }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('Passed.'), rval )
===

=== With no match

<?if test.match(/foo/) ?>
Failed.
<?end?>

---
assert_nothing_raised { template.test = "bar" }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe(), rval )
===

=== Match with binding operator

<?if test =~ /foo/ ?>
Passed.
<?end?>

---
assert_nothing_raised { template.test = "foo" }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('Passed.'), rval )
===

=== Simple with unexecuted else

<?if test?>
Passed.
<?else?>
Failed.
<?end?>

---
assert_nothing_raised { template.test = true }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('Passed.'), rval )
===


=== Simple with executed else

<?if test?>
Failed.
<?else?>
Passed.
<?end?>

---
assert_nothing_raised { template.test = false }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('Passed.'), rval )
===

=== Complex with success

<?if test > 5?>
Passed.
<?else?>
Failed.
<?end?>

---
assert_nothing_raised { template.test = 15 }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('Passed.'), rval )
===

=== Complex with failure

<?if test <= 5?>
Failed.
<?else?>
Passed.
<?end?>

---
assert_nothing_raised { template.test = 15 }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('Passed.'), rval )
===

=== Complex2

<?if test > 5 or test == 0?>
Passed.
<?else?>
Failed.
<?end?>

---
assert_nothing_raised { template.test = 0 }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('Passed.'), rval )
===

=== Inside iterator
<?yield foo from test.each?>
<?if foo?>
Passed.
<?else?>
Failed.
<?end?>
<?end yield?>
---
assert_nothing_raised { template.test = [true] }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('Passed.'), rval )
===

=== Inside iterator with comparison
<?yield foo from test.each?>
<?if foo == "bar"?>
Passed.
<?else?>
Failed.
<?end?>
<?end yield?>
---
assert_nothing_raised { template.test = ["bar"] }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe('Passed.'), rval )
===

### For directive
=== Simple

<?for item in tests ?>
	<?attr item?>
<?end?>

---
assert_nothing_raised { template.tests = %w{passed passed passed} }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe(/passed.*passed.*passed/m), rval )
===

=== Multiple items

<?for key, val in tests ?>
	<?attr key?>: <?attr val?>
<?end for?>

---
assert_nothing_raised { template.tests = {'uno' => 'Passed'} }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe(/uno:/,/Passed/), rval )
===

=== With methodchain

<?for word, length in tests.collect {|item| [item, item.length]}.
	sort_by {|item| item[1]} ?>
	<?attr word?>: <?attr length?>
<?end for?>

---
assert_nothing_raised { template.tests = %w{gronk bizzle foo} }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( templateContentRe(/foo:/,/3/,/gronk:/,/5/,/bizzle:/,/6/), rval )
===


=== Array of Hashes

<?for entry in svn_ret?>
	<?call entry.inspect?>
<?end for?>

---
aoh = [{:foo => 1, :bar => 2}, {:baz => 3, :bim => 4}]
assert_nothing_raised { template.svn_ret = aoh }
assert_nothing_raised { rval = template.render }
debugMsg "\n" + hruleSection( rval, "Rendered" )
assert_match( /\{/, rval )
assert_match( /:foo/, rval )
assert_match( /:bar/, rval )
assert_match( /:baz/, rval )
assert_match( /:bim/, rval )
===


### Yield directive
=== Simple

<?yield item from tests.each ?>
	<?attr item?>
<?end?>

---
assert_nothing_raised { template.tests = %w{passed passed passed} }
assert_nothing_raised { rval = template.render }
assert_match( templateContentRe(/passed.*passed.*passed/m), rval )
===

=== Simple Two Args

<?yield key, value from tests.each ?>
	<?attr key ?>: <?attr value ?>
<?end?>

---
assert_nothing_raised { template.tests = {:foo => "passed", :bar => "passed"} }
assert_nothing_raised { rval = template.render }
assert_match( templateContentRe(/(foo|bar):.*passed.*(foo|bar):.*passed/m), rval )
===

=== Non Each Iteration

<?yield match from tests.scan(%r{\w+}) ?>
	<?attr match?>
<?end?>

---
assert_nothing_raised { template.tests = "passed the test" }
assert_nothing_raised { rval = template.render }
assert_match( templateContentRe(/passed.*the.*test/m), rval )
===


### Include directive
=== Simple

<?include test.incl?>

---
assert_nothing_raised { rval = template.render }
assert_match( templateContentRe(/passed\./i), rval )
===

=== Recursive

<?include outerTest.incl ?>

---
assert_nothing_raised { rval = template.render }
assert_match( templateContentRe(/Outer\..*Passed\./m), rval )
===

=== Circular

<?include circular1.incl ?>

---
assert_nothing_raised { rval = template.render }
expected = /.*<!-- Template for circular include test -->.*circular1/m +
	/.*<!-- Template for circular include test -->.*circular2/m +
	/.*<!-- Arrow::TemplateError: Include circular1.incl: Circular include: /m +
	/circular1.incl -> circular2.incl -> circular1.incl -->.*/m
assert_match( templateContentRe(expected), rval )
===

=== With Identifier

<?include subtemplate.incl as sub?>

---
assert_nothing_raised { rval = template.sub }
assert_instance_of Arrow::Template, rval

assert_nothing_raised { template.sub.test = "Passed." }
assert_nothing_raised { rval = template.render }
assert_match( templateContentRe(/Passed\./), rval )
===

=== With Subdirectory

<?include subdir/include.incl?>

---
assert_nothing_raised { template.test = "Passed." }
assert_nothing_raised { rval = template.render }
assert_match( templateContentRe(/Passed\./), rval )
===


=== With Subdirectory And Identifier

<?include subdir/include.incl as sub?>

---
assert_nothing_raised { rval = template.sub }
assert_instance_of Arrow::Template, rval

assert_nothing_raised { template.sub.test = "Passed." }
assert_nothing_raised { rval = template.render }
assert_match( templateContentRe(/Passed\./), rval )
===


### Import directive
=== Simple

<?import foo?>
<?attr foo?>

---
superTemplate = Arrow::Template::new( "<?attr subtempl?>" )
superTemplate.foo = "Passed."
superTemplate.subtempl = template

assert_nothing_raised { rval = superTemplate.render }
assert_match( templateContentRe(/Passed\./), rval )
===

=== List

<?import foo, bar?>
<?attr foo?> <?attr bar?>

---
superTemplate = Arrow::Template::new( "<?attr subtempl?>" )
superTemplate.foo = "Passed foo."
superTemplate.bar = "Passed bar."
superTemplate.subtempl = template

assert_nothing_raised { rval = superTemplate.render }
assert_match( templateContentRe(/Passed foo\./,/Passed bar\./), rval )
===

=== Aliased

<?import foo as bar?>
<?attr bar?>

---
superTemplate = Arrow::Template::new( "<?attr subtempl?>" )
superTemplate.foo = "Passed."
superTemplate.subtempl = template

assert_nothing_raised { rval = superTemplate.render }
assert_match( templateContentRe(/Passed\./), rval )
===

=== Aliased List

<?import foo as bar, bar as foo?>
<?attr foo?> <?attr bar?>

---
superTemplate = Arrow::Template::new( "<?attr subtempl?>" )
superTemplate.foo = "Passed foo."
superTemplate.bar = "Passed bar."
superTemplate.subtempl = template

assert_nothing_raised { rval = superTemplate.render }
assert_match( templateContentRe(/Passed bar\./,/Passed foo\./), rval )
===

=== Mixed List

<?import foo, bar as superbar?>
<?attr foo?> <?attr bar?> <?attr superbar?>

---
superTemplate = Arrow::Template::new( "<?attr subtempl?>" )
superTemplate.foo = "Passed foo."
superTemplate.bar = "Passed bar."
superTemplate.subtempl = template

template.bar = "Passed real bar."

assert_nothing_raised { rval = superTemplate.render }
pat = templateContentRe(/Passed foo\./,/Passed real bar\./,/Passed bar\./)
assert_match( pat, rval )
===
