#
# A "hello world" Arrow applet
#

require 'arrow/applet'

# Define the applet class; inherit from the base applet class.
class Hello < Arrow::Applet

	# Applet signature
	Signature = {
		:name => "Hello World",
		:description => "This is yet another implementation of Hello World",
		:maintainer => "ged@FaerieMUD.org",
		:default_action => 'greet',
	}

	# Define the 'greet' (default) action
	def greet_action( txn, name=nil )
		name ||= "world"

		return <<-EOF
        <html>
		<head><title>Hello</title></head>
		<body><p>Hello, #{name}.</p></body>
        </html>
	    EOF
	end

end




