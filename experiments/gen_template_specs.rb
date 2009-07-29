#!/usr/bin/env ruby

# Convert the test::unit auto-generated tests into equivalent specs

### Read test data into a Hash for later
TestTemplates = {}

inTemplate = seenEnd = false;
section, template, part = nil
linenum = 0

# Read this file, skipping lines until the __END__ token. Then start
# reading the tests.
File.foreach( 'tests/template.tests.rb' ) do |line|
	linenum += 1
	if /^__END__/ =~ line then seenEnd = true; next end
	$stderr.puts "#{linenum}: #{line.chomp}"
	next unless seenEnd
	line.chomp!

	case line

	# Directive changes look like:
	# # Set directive
	when /^### (\w+) directive/i
		section = $1.downcase.to_sym
		TestTemplates[ section ] ||= {}

	when /^#/
		next

	# Subtests for current directive look like:
	# === Simple
	when /^===\s*(.+)/
		next unless section
		template = $1.downcase
		TestTemplates[section][template] = {
			:template => '',
			:code => '',
			:linenumber => linenum,
		}
		part = :template
		$stderr.puts "Found template '%s' for the '%s' section at line %d" %
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
end

### Generate methods for all of the test data
TestTemplates.each do |section, templates|
	templates.each do |template_name, content|
		methodName = "test_%s_%s" %
			[ section, template_name ]
		$stderr.puts "Generating test method #{methodName}"

		# If there's no code with the template, then just expect a
		# failure in instantiation.
		if content[:code].empty?
			code = <<-END_CODE
it "raises an error when parsing a template with a #{template_name} #{section}" do
	source = <<-'TEMPLATE_END'.gsub(/^\t/, '')
	#{content[:template].gsub(/^/, "\t")}
	TEMPLATE_END

	expect { Arrow::Template.new(source) }.to raise_error( Arrow::TemplateError )
end

END_CODE
		else
			code = <<-END_CODE
it "implements #{template_name} #{section}s" do
	source = <<-'TEMPLATE_END'.gsub(/^\t/, '')
	#{content[:template].gsub(/^/, "\t")}
	TEMPLATE_END

	template = Arrow::Template.new( source )
	template._config[:debuggingComments] = true if $DEBUG

	#{content[:code].gsub(/^/, "\t")}
end

			END_CODE
		end

		$stderr.puts "Generating test (line #{content[:linenumber]})"
		$stdout.puts( code )
	end
end

