#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rubygems'
require 'spec'
require 'apache/fakerequest'
require 'arrow'
require 'arrow/dispatcher'
require 'arrow/config-loaders/yaml'

require 'spec/lib/helpers'
require 'spec/lib/matchers'
require 'spec/lib/constants'


include Arrow::TestConstants


#####################################################################
###	C O N T E X T S
#####################################################################

describe Arrow::Template do
	include Arrow::SpecHelpers

	before( :all ) do
		setup_logging( :debug )
		specdir = Pathname( __FILE__ ).dirname.parent
		@datadir = specdir + 'data/templates'
	end

	after( :all ) do
		reset_logging()
	end


	it "supports Arrow::Cache's interface for memory-size introspection" do
		tmplfile = @datadir + 'loadtest.tmpl'
		tmpl = Arrow::Template.load( tmplfile )
		tmpl.memsize.should == tmplfile.size
	end


	it "should report a memory size of 0 for a blank template" do
		Arrow::Template.new.memsize.should == 0
	end


	it "adds attributes for <?attr?> processing-instructions" do
		tmplfile = @datadir + 'loadtest.tmpl'
		template = Arrow::Template.load( tmplfile )
		template._attributes.should include( 'mooselips' )
		template._attributes.should include( 'queenofallbroccoli' )
	end


	it "renders Arrays by concatenating its members" do
		Arrow::Template.new.render_objects(%w[foo bar]).should == 'foobar'
	end


	it "calls :before_rendering before rendering for nodes that respond to it" do
		node = mock( "template node" )
		template = Arrow::Template.new

		node.should_receive( :before_rendering ).with( template )

		template.render([ node ])
	end


	it "calls :after_rendering after rendering for nodes that respond to it" do
		node = mock( "template node" )
		template = Arrow::Template.new

		node.should_receive( :after_rendering ).with( template )

		template.render([ node ])
	end


	it "renders the template by joining rendered nodes with the default string separator" do
		rval = nil
		template = Arrow::Template.new( "<?attr foo ?><?attr bar ?>" )
		template.foo = "[foo]"
		template.bar = "[bar]"

		begin
			sep = $,
			$, = ':'
			rval = template.render
		ensure
			$, = sep
		end

		rval.should == "[foo]:[bar]"
	end


	it "implements simple imports" do
		source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
			<?import foo?>
			<?attr foo?>
		TEMPLATE_END

		template = Arrow::Template.new( source )
		template._config[:debuggingComments] = true if $DEBUG

		container = Arrow::Template.new( "<?attr subtempl?>" )
		container.foo = "Passed."
		container.subtempl = template

		container.render.should =~ /Passed\./
	end

	it "implements list imports" do
		source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
			<?import foo, bar?>
			<?attr foo?> <?attr bar?>
		TEMPLATE_END

		template = Arrow::Template.new( source )
		template._config[:debuggingComments] = true if $DEBUG

		container = Arrow::Template.new( "<?attr subtempl?>" )
		container.foo = "Passed foo."
		container.bar = "Passed bar."
		container.subtempl = template

		container.render.should =~ /Passed foo\..*Passed bar\./
	end

	it "implements mixed list imports" do
		source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
			<?import foo, bar as superbar?>
			<?attr foo?> <?attr bar?> <?attr superbar?>
		TEMPLATE_END

		template = Arrow::Template.new( source )
		template._config[:debuggingComments] = true if $DEBUG

		container = Arrow::Template.new( "<?attr subtempl?>" )
		container.foo = "Passed foo."
		container.bar = "Passed bar."
		container.subtempl = template

		template.bar = "Passed real bar."

		container.render.should =~ /Passed foo\..*Passed real bar\..*Passed bar\./
	end

	it "implements aliased imports" do
		source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
			<?import foo as bar?>
			<?attr bar?>
		TEMPLATE_END

		template = Arrow::Template.new( source )
		template._config[:debuggingComments] = true if $DEBUG

		container = Arrow::Template.new( "<?attr subtempl?>" )
		container.foo = "Passed."
		container.subtempl = template

		container.render.should =~ /Passed\./
	end

	it "implements unknown pi (ignored) imports" do
		source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
			<?xml version="1.0" encoding="utf-8"?>
		TEMPLATE_END

		Arrow::Template.new( source ).render.
			should include( '<?xml version="1.0" encoding="utf-8"?>' )
	end

	it "implements aliased list imports" do
		source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
			<?import foo as bar, bar as foo?>
			<?attr foo?> <?attr bar?>
		TEMPLATE_END

		template = Arrow::Template.new( source )
		template._config[:debuggingComments] = true if $DEBUG

		container = Arrow::Template.new( "<?attr subtempl?>" )
		container.foo = "Passed foo."
		container.bar = "Passed bar."
		container.subtempl = template

		container.render.should =~ /Passed bar\..*Passed foo\./
	end

	# it "implements simple sets" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 		<?set time = Time.now ?>
	# 	TEMPLATE_END
	# 
	# 	this_moment = Time.now
	# 	Time.should_receive( :now ).and_return( this_moment )
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 	# template['time'].should == this_moment
	# 
	# 	template.render.should include( this_moment.to_s )
	# end
	# 
	# it "implements rendered later sets" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?set val = "Passed."?>
	# 	<?attr val?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_respond_to template, :val
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_not_match( /error/i, rval )
	# 	assert_match( templateContentRe("Passed."), rval )
	# 
	# end
	# 
	# it "implements method chain sets" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?set time = Time.now.strftime( "%Y%m%d %H:%M:%S" ) ?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { rval = template['time'] }
	# 	debugMsg "template['time'] => %p" % rval
	# 
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe(), rval )
	# 
	# end
	# 
	# it "implements simple renders" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?render foo as bar in simplerender.tmpl ?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		debugMsg "Setting outer template's 'foo' to 'baz'"
	# 	assert_nothing_raised { template.foo = "baz" }
	# 	assert_equal "baz", template.foo
	# 
	# 	assert_nothing_raised {	rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Simple Render: baz'), rval )
	# 
	# end
	# 
	# it "implements with import renders" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	Something: <?attr something?>
	# 	<?render foo as bar in importrender.tmpl ?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		debugMsg "Setting outer template's 'foo' to 'baz'"
	# 	assert_nothing_raised { template.foo = "baz" }
	# 	assert_equal "baz", template.foo
	# 
	# 	debugMsg "Setting outer template's 'something' to 'sasquatch'"
	# 	assert_nothing_raised { template.something = "sasquatch" }
	# 
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Something:', 'sasquatch','Bar:', 
	# 	                                'baz and sasquatch'), rval )
	# 
	# end
	# 
	# it "implements with complex methodchain renders" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?render pairs['hash'] as pairs in recurse.tmpl ?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		pairs = {
	# 		"integer" => 1,
	# 		"hash" => {
	# 			"bar" => 1,
	# 			"foo" => 2,
	# 			"subsubhash" => {"hope, faith" => "and charity"},
	# 		},
	# 		"string" => "A string",
	# 	}
	# 	debugMsg "Setting outer template's 'pairs' to %p" % pairs
	# 	assert_nothing_raised { template.pairs = pairs }
	# 
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe("Key => subsubhash\n  Val => \nKey => hope, faith\n  Val => and charity\n\n\nKey => foo\n  Val => 2\nKey => bar\n  Val => 1"), rval )
	# 
	# end
	# 
	# it "implements recursion renders" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?render pairs as pairs in recurse.tmpl ?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		pairs = {
	# 		"integer" => 1,
	# 		"hash" => {
	# 			"bar" => 1,
	# 			"foo" => 2,
	# 			"subsubhash" => {"hope, faith" => "and charity"},
	# 		},
	# 		"string" => "A string",
	# 	}
	# 	debugMsg "Setting outer template's 'pairs' to %p" % pairs
	# 	assert_nothing_raised { template.pairs = pairs }
	# 
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe("Key => integer\n  Val => 1\nKey => hash\n  Val => \nKey => subsubhash\n  Val => \nKey => hope, faith\n  Val => and charity\n\n\nKey => foo\n  Val => 2\nKey => bar\n  Val => 1\n\n\nKey => string\n  Val => A string"), rval )
	# 
	# end
	# 
	# it "raises an error when parsing a template with a malformed1 call" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?call?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	expect { Arrow::Template.new(source) }.to raise_error( Arrow::TemplateError )
	# end
	# 
	# it "implements simple calls" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?call test?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		debugMsg "Testing getter"
	# 	assert_nothing_raised { rval = template.test }
	# 	assert_equal nil, rval
	# 
	# 	debugMsg "Testing setter"
	# 	assert_nothing_raised { template.test = "foo" }
	# 	assert_equal "foo", template.test
	# 
	# 	assert_nothing_raised {	rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('foo'), rval )
	# 
	# end
	# 
	# it "raises an error when parsing a template with a malformed2 call" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?call "%s" tests ?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	expect { Arrow::Template.new(source) }.to raise_error( Arrow::TemplateError )
	# end
	# 
	# it "implements idsub test calls" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?call test ? "test" : "no test"?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = true }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe(/^test/), rval )
	# 
	# end
	# 
	# it "implements with format and additional quotes calls" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?call '|%-15s|' % test?>
	# 	'Some more "quoted" stuff to make sure the match doesn't grab them.
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		testdata = ("x" * 5)
	# 
	# 	assert_nothing_raised { template.test = testdata }
	# 	assert_equal testdata, template.test
	# 
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe(/\|x{5}\s{10}\|.*them\./m), rval )
	# 
	# end
	# 
	# it "implements with format calls" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?call '|%-15s|' % test?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		testdata = ("x" * 5)
	# 
	# 	assert_nothing_raised { template.test = testdata }
	# 	assert_equal testdata, template.test
	# 
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe(/\|x{5}\s{10}\|/), rval )
	# 
	# end
	# 
	# it "implements inside iterator ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 		<?yield foo from test.each?>
	# 	<?if foo?>
	# 	Passed.
	# 	<?else?>
	# 	Failed.
	# 	<?end?>
	# 	<?end yield?>
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = [true] }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements with match ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?if test.match(/foo/) ?>
	# 	Passed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = "foo" }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements simple ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?if test?>
	# 	Passed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = true }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements methodchain with question mark ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 		<?if test.is_a?( Arrow::Exception ) ?>
	# 	Passed.
	# 	<?else?>
	# 	Failed.
	# 	<?end?>
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		obj = Arrow::Exception.new
	# 	assert_nothing_raised { template.test = obj }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements simple with mismatched end ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?if test?>
	# 	Passed.
	# 	<?end for?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = true }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements complex with success ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?if test > 5?>
	# 	Passed.
	# 	<?else?>
	# 	Failed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = 15 }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements complex with failure ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?if test <= 5?>
	# 	Failed.
	# 	<?else?>
	# 	Passed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = 15 }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements with no match ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?if test.match(/foo/) ?>
	# 	Failed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = "bar" }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe(), rval )
	# 
	# end
	# 
	# it "implements complex2 ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?if test > 5 or test == 0?>
	# 	Passed.
	# 	<?else?>
	# 	Failed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = 0 }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements simple with executed else ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?if test?>
	# 	Failed.
	# 	<?else?>
	# 	Passed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = false }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements match with binding operator ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?if test =~ /foo/ ?>
	# 	Passed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = "foo" }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements simple with unexecuted else ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?if test?>
	# 	Passed.
	# 	<?else?>
	# 	Failed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = true }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements simple with explicit end ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?if test?>
	# 	Passed.
	# 	<?end if?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = true }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements inside iterator with comparison ifs" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 		<?yield foo from test.each?>
	# 	<?if foo == "bar"?>
	# 	Passed.
	# 	<?else?>
	# 	Failed.
	# 	<?end?>
	# 	<?end yield?>
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = ["bar"] }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements simple exports" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?attr headsections ?>
	# 	<?attr subtemplate ?>
	# 	<?attr tailsections ?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		template.subtemplate = Arrow::Template.load( "export.tmpl" )
	# 
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe("head", "content", "tail"), rval )
	# 
	# end
	# 
	# it "implements inside iterator unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 		<?yield foo from test.each?>
	# 	<?unless foo?>
	# 	Passed.
	# 	<?else?>
	# 	Failed.
	# 	<?end?>
	# 	<?end yield?>
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = [false] }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements with match unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?unless test.match(/foo/) ?>
	# 	Failed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = "foo" }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe(), rval )
	# 
	# end
	# 
	# it "implements simple unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?unless test?>
	# 	Passed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = false }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements methodchain with question mark unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 		<?unless test.is_a?( Arrow::Exception ) ?>
	# 	Passed.
	# 	<?else?>
	# 	Failed.
	# 	<?end?>
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		obj = Object.new
	# 	assert_nothing_raised { template.test = obj }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements simple with mismatched end unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?unless test?>
	# 	Passed.
	# 	<?end for?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = false }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements complex with success unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?unless test > 5?>
	# 	Passed.
	# 	<?else?>
	# 	Failed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = 2 }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements complex with failure unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?unless test <= 5?>
	# 	Failed.
	# 	<?else?>
	# 	Passed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = 2 }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements with no match unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?unless test.match(/foo/) ?>
	# 	Passed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = "bar" }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements complex2 unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?unless test > 5 or test == 0?>
	# 	Failed.
	# 	<?else?>
	# 	Passed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = 0 }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements simple with executed else unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?unless test?>
	# 	Failed.
	# 	<?else?>
	# 	Passed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = true }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements match with binding operator unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?unless test =~ /foo/ ?>
	# 	Passed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = "bar" }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements simple with unexecuted else unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?unless test?>
	# 	Passed.
	# 	<?else?>
	# 	Failed.
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = false }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements simple with explicit end unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?unless test?>
	# 	Passed.
	# 	<?end unless?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = false }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements inside iterator with comparison unlesss" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 		<?yield foo from test.each?>
	# 	<?unless foo == "bar"?>
	# 	Passed.
	# 	<?else?>
	# 	Failed.
	# 	<?end?>
	# 	<?end yield?>
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = ["foo"] }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('Passed.'), rval )
	# 
	# end
	# 
	# it "implements simple selectlists" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 		<?selectlist categories ?>
	# 	<?end?>
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		template.categories = %w[code rant music]
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 
	# 	list = <<-EOF
	# 	<select name="categories">
	# 	  <option value="code">code</option>
	# 	  <option value="rant">rant</option>
	# 	  <option value="music">music</option>
	# 	</select>
	# 	EOF
	# 
	# 	assert_match( templateContentRe(list), rval )
	# 
	# end
	# 
	# it "implements named selectlists" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 		<?selectlist category FROM categories ?>
	# 	<?end?>
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		template.categories = %w[code rant music parrots]
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 
	# 	list = <<-EOF
	# 	<select name="category">
	# 	  <option value="code">code</option>
	# 	  <option value="rant">rant</option>
	# 	  <option value="music">music</option>
	# 	  <option value="parrots">parrots</option>
	# 	</select>
	# 	EOF
	# 
	# 	assert_match( templateContentRe(list), rval )
	# 
	# end
	# 
	# it "implements simple fors" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?for item in tests ?>
	# 		<?attr item?>
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.tests = %w{passed passed passed} }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe(/passed.*passed.*passed/m), rval )
	# 
	# end
	# 
	# it "implements with methodchain fors" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?for word, length in tests.collect {|item| [item, item.length]}.
	# 		sort_by {|item| item[1]} ?>
	# 		<?attr word?>: <?attr length?>
	# 	<?end for?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.tests = %w{gronk bizzle foo} }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe(/foo:/,/3/,/gronk:/,/5/,/bizzle:/,/6/), rval )
	# 
	# end
	# 
	# it "implements array of hashes fors" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?for entry in svn_ret?>
	# 		<?call entry.inspect?>
	# 	<?end for?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		aoh = [{:foo => 1, :bar => 2}, {:baz => 3, :bim => 4}]
	# 	assert_nothing_raised { template.svn_ret = aoh }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( /\{/, rval )
	# 	assert_match( /:foo/, rval )
	# 	assert_match( /:bar/, rval )
	# 	assert_match( /:baz/, rval )
	# 	assert_match( /:bim/, rval )
	# 
	# end
	# 
	# it "implements iterator in evaled region fors" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?for key in purchases.keys ?>
	# 	  <?if foo.key?(key) ?>
	# 	  Passed.
	# 	  <?end if?>
	# 	<?end for ?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		purchases = {"test" => 7}
	# 	foo = {"test" => 3}
	# 	assert_nothing_raised { template.purchases = purchases }
	# 	assert_nothing_raised { template.foo = foo }
	# 	assert_nothing_raised { rval = template.render }
	# 	assert_match( templateContentRe(/Passed\./), rval )
	# 
	# 
	# end
	# 
	# it "implements multiple items fors" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?for key, val in tests ?>
	# 		<?attr key?>: <?attr val?>
	# 	<?end for?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.tests = {'uno' => 'Passed'} }
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe(/uno:/,/Passed/), rval )
	# 
	# end
	# 
	# it "implements cannot override definitions ivar fors" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?for definitions in array ?>
	# 		Failed.
	# 	<?end for?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		array = [:foo]
	# 	assert_nothing_raised { rval = template.render }
	# 	assert_match( /<!--.*ScopeError.*-->/, rval )
	# 
	# end
	# 
	# it "implements simple yields" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?yield item from tests.each ?>
	# 		<?attr item?>
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.tests = %w{passed passed passed} }
	# 	assert_nothing_raised { rval = template.render }
	# 	assert_match( templateContentRe(/passed.*passed.*passed/m), rval )
	# 
	# end
	# 
	# it "implements non each iteration yields" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?yield match from tests.scan(%r{\w+}) ?>
	# 		<?attr match?>
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.tests = "passed the test" }
	# 	assert_nothing_raised { rval = template.render }
	# 	assert_match( templateContentRe(/passed.*the.*test/m), rval )
	# 
	# end
	# 
	# it "implements simple two args yields" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?yield key, value from tests.each ?>
	# 		<?attr key ?>: <?attr value ?>
	# 	<?end?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.tests = {:foo => "passed", :bar => "passed"} }
	# 	assert_nothing_raised { rval = template.render }
	# 	assert_match( templateContentRe(/(foo|bar):.*passed.*(foo|bar):.*passed/m), rval )
	# 
	# end
	# 
	# it "implements recursive includes" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?include outerTest.incl ?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { rval = template.render }
	# 	assert_match( templateContentRe(/Outer\..*Passed\./m), rval )
	# 
	# end
	# 
	# it "implements simple includes" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?include test.incl?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { rval = template.render }
	# 	assert_match( templateContentRe(/passed\./i), rval )
	# 
	# end
	# 
	# it "implements circular includes" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?include circular1.incl ?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { rval = template.render }
	# 	expected = /.*<!-- Template for circular include test -->.*circular1/m +
	# 		/.*<!-- Template for circular include test -->.*circular2/m +
	# 		/.*<!-- Arrow::TemplateError: Include circular1.incl: Circular include: /m +
	# 		/circular1.incl -> circular2.incl -> circular1.incl -->.*/m
	# 	assert_match( templateContentRe(expected), rval )
	# 
	# end
	# 
	# it "implements with subdirectory and identifier includes" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?include subdir/include.incl as sub?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { rval = template.sub }
	# 	assert_instance_of Arrow::Template, rval
	# 
	# 	assert_nothing_raised { template.sub.test = "Passed." }
	# 	assert_nothing_raised { rval = template.render }
	# 	assert_match( templateContentRe(/Passed\./), rval )
	# 
	# end
	# 
	# it "implements with subdirectory includes" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?include subdir/include.incl?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { template.test = "Passed." }
	# 	assert_nothing_raised { rval = template.render }
	# 	assert_match( templateContentRe(/Passed\./), rval )
	# 
	# end
	# 
	# it "implements with identifier includes" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?include subtemplate.incl as sub?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		assert_nothing_raised { rval = template.sub }
	# 	assert_instance_of Arrow::Template, rval
	# 
	# 	assert_nothing_raised { template.sub.test = "Passed." }
	# 	assert_nothing_raised { rval = template.render }
	# 	assert_match( templateContentRe(/Passed\./), rval )
	# 
	# end
	# 
	# it "raises an error when parsing a template with a malformed1 attribute" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?attr?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	expect { Arrow::Template.new(source) }.to raise_error( Arrow::TemplateError )
	# end
	# 
	# it "implements simple attributes" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?attr test?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		debugMsg "Testing getter"
	# 	assert_nothing_raised { rval = template.test }
	# 	assert_equal nil, rval
	# 
	# 	debugMsg "Testing setter"
	# 	assert_nothing_raised { template.test = "foo" }
	# 	assert_equal "foo", template.test
	# 
	# 	assert_nothing_raised {	rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe('foo'), rval )
	# 
	# end
	# 
	# it "raises an error when parsing a template with a malformed2 attribute" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?attr '%s' test ?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	expect { Arrow::Template.new(source) }.to raise_error( Arrow::TemplateError )
	# end
	# 
	# it "implements with format attributes" do
	# 	source = <<-'TEMPLATE_END'.gsub(/^\t{3}/, '')
	# 
	# 	<?attr '|%-15s|' % test?>
	# 
	# 
	# 	TEMPLATE_END
	# 
	# 	template = Arrow::Template.new( source )
	# 	template._config[:debuggingComments] = true if $DEBUG
	# 
	# 		testdata = ("x" * 5)
	# 
	# 	assert_nothing_raised { template.test = testdata }
	# 	assert_equal testdata, template.test
	# 
	# 	assert_nothing_raised { rval = template.render }
	# 	debugMsg "\n" + hruleSection( rval, "Rendered" )
	# 	assert_match( templateContentRe(/\|x{5}\s{10}\|/), rval )
	# 
	# end

end

# vim: set nosta noet ts=4 sw=4:

