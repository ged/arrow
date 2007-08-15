#!/usr/bin/env ruby
# 
# This file contains the Arrow::Applet class, which is an abstract base
# class for Arrow applets.
# 
# == Synopsis
#
#   require 'arrow/applet'
#
#	class MyApplet < Arrow::Applet
#		applet_name "My Applet"
#		applet_description 'Displays a block of whatever character is ' +
#			'passed as argument'
#		applet_maintainer 'Michael Granger <mgranger@rubycrafters.com>'
#		applet_version '1.01'
#		default_action :form
#
#       # Define the 'display' action
#       def_action :display do |txn|
#           char = txn.vargs[:char] || 'x'
#           char_page = self.make_character_page( char )
#           templ = self.load_template( :main )
#           templ.char_page = char_page
#
#           return templ
#       end
#		template :main, "main.tmpl"
#
#       # Define the 'form' action -- display a form that can be used to set
#       # the character the block is composed of. Save the returned proxy so
#       # the related signature values can be set.
#       formaction = def_action :form do |txn|
#           templ = self.load_template( :form )
#           templ.txn = txn
#           return templ
#       end
#       formaction.template = "form.tmpl"
#
#       # Make a page full of 
#       def make_character_page( char )
#           page = ''
#           40.times do
#               page << (char * 80) << "\n"
#           end
#       end
#
#	end
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

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/object'
require 'arrow/formvalidator'


### An abstract base class for Arrow applets. Provides execution logic,
### argument-parsing/untainting/validation, and templating through an injected
### factory.
class Arrow::Applet < Arrow::Object

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	### Applet signature struct. The fields are as follows:
	### [<b>name</b>]
	###	  The name of the applet; used for introspection and reports.
	### [<b>description</b>]
	###	  The description of the applet; used for introspection.
	### [<b>maintainer</b>]
	###	  The name of the maintainer for reports and introspection.
	### [<b>version</b>]
	###	  The version or revision number of the applet, which can be
	###	  any object that has a #to_s method.
	### [<b>default_action</b>]
	###	  The action that will be run if no action is specified.
	### [<b>templates</b>]
	###	  A hash of templates used by the applet. The keys are Symbol
	###	  identifiers which will be used for lookup, and the values are the
	###	  paths to template files.
	### [<b>validator_profiles</b>]
	###	  A hash containing profiles for the built in form validator, one
	###	  per action. See the documentation for FormValidator for the format
	###	  of each profile hash.
	SignatureStruct = Struct.new( :name, :description, :maintainer,
		:version, :config, :default_action, :templates, :validator_profiles,
		:appicon )

	# Default-generators for Signatures which are missing one or more of the
	# optional pairs.
	SignatureStructDefaults = {
		:name				=> proc {|rawsig, klass| klass.name},
		:description		=> "(none)",
		:maintainer			=> "", # Workaround for RDoc
		:version			=> nil, # Wordaround for RDoc
		:default_action		=> '_default',
		:config				=> {},
		:templates			=> {},
		:validator_profiles	=> {
			:__default__		=> {
				:optional			=> [:action],
				:constraints		=> {
					:action => /^\w+$/,
				},
			},
		},
		:appicon			=> 'application-x-executable.png',
	}

	SignatureStructDefaults[:version] = proc {|rawsig, klass|
		if klass.const_defined?( :SVNRev )
			return klass.const_get( :SVNRev ).gsub(/Rev: /, 'r')
		elsif klass.const_defined?( :Version )
			return klass.const_get( :Version )
		elsif klass.const_defined?( :Revision )
			return klass.const_get( :Revision )
		elsif klass.const_defined?( :Rcsid )
			return klass.const_get( :Rcsid )
		else
			begin
				File.stat( klass.sourcefile ).mtime.strftime('%Y%m%d-%M:%H')
			rescue
			end
		end
	}


	### Proxy into the Applet's signature for a given action.
	class SigProxy

		### Create a new proxy into the given +klass+'s Signature for the
		### specified +action_name+.
		def initialize( action_name, klass )
			@action_name = action_name.to_s.intern
			@signature = klass.signature
			@signature[:templates] ||= {}
			@signature[:validator_profiles] ||= {}
		end


		### Get the template associated with the same name as the proxied
		### action.
		def template
			@signature[:templates][@action_name]
		end


		### Set the template associated with the same name as the proxied
		### action to +tmpl+.
		def template=( tmpl )
			@signature[:templates][@action_name] = tmpl
		end

		
		### Get the validator profile associated with the same name as the
		### proxied action.
		def validator_profile
			@signature[:validator_profiles][@action_name]
		end


		### Set the validator profile associated with the same name as the
		### proxied action to +hash+.
		def validator_profile=( hash )
			@signature[:validator_profiles][@action_name] = hash
		end

	end # class SigProxy


	# The array of loaded applet classes (derivatives) and an array of
	# newly-loaded ones.
	@derivatives = []
	@newly_loaded = []


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	class << self
		# The Array of loaded applet classes (derivatives)
		attr_reader :derivatives

		# The Array of applet classes that were loaded by the most recent call
		# to .load.
		attr_reader :newly_loaded

		# The file containing the applet's class definition
		attr_accessor :filename
	end


	### Set the path for the template specified by +sym+ to +path+.
	def self::template( sym, path=nil )
		case sym
		when Symbol, String
			self.signature.templates[ sym ] = path
			
		when Hash
			self.signature.templates.merge!( sym )
			
		else
			raise ArgumentError, "cannot convert %s to Symbol" % [ sym ]
		end
	end


	### Set the name of the applet to +name+.
	def self::applet_name( name )
		self.signature.name = name
	end
	
	
	### Set the description of the applet to +desc+.
	def self::applet_description( desc )
		self.signature.description = desc		
	end
	
	
	### Set the contact information for the maintainer of the applet to +info+.
	def self::applet_maintainer( info )
		self.signature.maintainer = info
	end


	### Set the contact information for the maintainer of the applet to +info+.
	def self::applet_version( ver )
		self.signature.version = ver
	end


	### Set the default action for the applet to +action+.
	def self::default_action( action )
		self.signature.default_action = action.to_s
	end
	deprecate_class_method :applet_default_action, :default_action


	### Set the validator +rules+ for the specified +action+.
	def self::validator( action, rules={} )
		self.signature.validator_profiles[ action ] = rules
	end


	### Set the appicon for the applet to +imgfile+.
	def self::appicon( imgfile )
		self.signature.appicon = imgfile
	end


	### Inheritance callback: register any derivative classes so they can be
	### looked up later.
	def self::inherited( klass )
		@inherited_from = true
		if defined?( @newly_loaded )
			@newly_loaded.push( klass )
			super
		else
			Arrow::Applet.inherited( klass )
		end
	end
	
	
	### Have any subclasses of this class been created?
	def self::inherited_from?
		@inherited_from
	end


	### Method definition callback: Check newly-defined action methods for
	### appropriate arity.
	def self::method_added( sym )
		if /^(\w+)_action$/.match( sym.to_s ) &&
				self.instance_method( sym ).arity.zero?
			raise ScriptError, "Inappropriate arity for #{sym}", caller(1)
		end
	end


	### Load any applet classes in the given file and return them.  Ignores
	### any class which has a subclass in the file unless +include_base_classes+
	### is set false
	def self::load( filename, include_base_classes=false )
		self.newly_loaded.clear

		# Load the applet file in an anonymous module. Any applet classes get
		# collected via the ::inherited hook into @newly_loaded
		Kernel.load( filename, true )

		newderivatives = @newly_loaded.dup
		@derivatives -= @newly_loaded
		@derivatives.push( *@newly_loaded )

		newderivatives.each do |applet|
			applet.filename = filename
		end

		unless include_base_classes
			newderivatives.delete_if do |applet|
				applet.inherited_from?
			end
		end
		
		return newderivatives
	end


	### Return the name of the applet class after stripping off any 
	### namespace-safe prefixes.
	def self::normalized_name
	    self.name.sub( /#<Module:0x\w+>::/, '' )
	end


	### Get the applet's signature (an
	### Arrow::Applet::SignatureStruct object).
	def self::signature
		@signature ||= make_signature()
	end


	### Returns +true+ if the applet class has a signature.
	def self::signature?
		!self.signature.nil?
	end


	### Signature lookup: look for either a constant or an instance
	### variable of the class that contains the raw signature hash, and
	### convert it to an Arrow::Applet::SignatureStruct object.
	def self::make_signature
		rawsig = nil
		if self.instance_variables.include?( "@signature" )
			rawsig = self.instance_variable_get( :@signature )
		elsif self.constants.include?( "Signature" )
			rawsig = self.const_get( :Signature )
		elsif self.constants.include?( "SIGNATURE" )
			rawsig = self.const_get( :SIGNATURE )
		else
			rawsig = {}
		end

		# Backward-compatibility: Rewrite the 'vargs' member as
		# 'validator_profiles' if 'vargs' exists and 'validator_profiles'
		# doesn't. 'vargs' member will be deleted regardless.
		rawsig[ :validator_profiles ] ||= rawsig.delete( :vargs ) if
			rawsig.key?( :vargs )

		# If the superclass has a signature, inherit values from it for
		# pairs that are missing.
		if self.superclass < Arrow::Applet && self.superclass.signature?
			self.superclass.signature.each_pair do |member,value|
				next if [:name, :description, :version].include?( member )
				if rawsig[member].nil?
					rawsig[ member ] = value.dup rescue value
				end
			end
		end

		# Apply sensible defaults for members that aren't defined
		SignatureStructDefaults.each do |key,val|
			next if rawsig[ key ]
			case val
			when Proc, Method
				rawsig[ key ] = val.call( rawsig, self )
			when Numeric, NilClass, FalseClass, TrueClass
				rawsig[ key ] = val
			else
				rawsig[ key ] = val.dup
			end
		end

		# Signature = Struct.new( :name, :description, :maintainer,
		# 	:version, :config, :default_action, :templates, :validatorArgs,
		# 	:monitors )
		members = SignatureStruct.members.collect {|m| m.intern}
		return SignatureStruct.new( *rawsig.values_at(*members) )
	end


	### Define an action for the applet. Transactions which include the
	### specified +name+ as the first directory of the uri after the one the
	### applet is assigned to will be passed to the given +block+. The
	### return value from this method is an Arrow::Applet::SigProxy which
	### can be used to set associated values in the applet's Signature; see
	### the Synopsis in lib/arrow/applet.rb for examples of how to use this.
	def self::def_action( name, &block )
		name = '_default' if name.to_s.empty?
		
		# Action must accept at least a transaction argument
		unless block.arity.nonzero?
			raise ScriptError,
				"Malformed action #{name}: must accept at least one argument"
		end

		methodName = "#{name}_action"
		define_method( methodName, &block )
		SigProxy.new( name, self )
	end


    deprecate_class_method :action, :def_action



	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new Arrow::Applet object with the specified +config+ (an
	### Arrow::Config object), +template_factory+ (an Arrow::TemplateFactory
	### object), and the +uri+ the applet will live under in the appserver (a
	### String).
	def initialize( config, template_factory, uri )
		@config				= config
		@template_factory	= template_factory
		@uri				= uri

		@signature			= self.class.signature.dup
		@run_count			= 0
		@total_utime		= 0
		@total_stime		= 0

		# Make a regexp out of all public <something>_action methods
		@actions = self.public_methods( true ).
			select {|meth| /^(\w+)_action$/ =~ meth }.
			collect {|meth| meth.gsub(/_action/, '') }
		@actions_regexp	= Regexp.new( "^(" + actions.join( '|' ) + ")$" )
	end


	######
	public
	######

	# The Arrow::Config object which contains the system's configuration.
	attr_accessor :config

	# The URI the applet answers to
	attr_reader :uri

	# The Struct that contains the configuration values for this applet
	attr_reader :signature

	# The number of times this particular applet object has been run
	attr_reader :run_count

	# The number of user seconds spent in this applet's #run method.
	attr_reader :total_utime

	# The number of system seconds spent in this applet's #run method.
	attr_reader :total_stime

	# The Arrow::TemplateFactory object used to load templates for the applet.
	attr_reader :template_factory

	# The list of all valid actions on the applet
	attr_reader :actions


	### Run the specified +action+ for the given +txn+ and the specified
	### +args+.
	def run( txn, action=nil, *args )
		starttimes = Process.times
		self.log.debug "Running %s" % [ self.signature.name ]

		action = nil if action.to_s.empty?
		action ||= @signature.default_action or
			raise Arrow::AppletError, "Missing default handler '#{default}'"

		# Do any initial preparation of the transaction that can be factored out
		# of all the actions.
		self.prep_transaction( txn )
		meth, *args = self.lookup_action_method( txn, action, *args )
		self.log.debug "Action method is: %p" % [meth]
		txn.vargs = self.make_validator( action, txn )
		
		# Now either pass control to the block, if given, or invoke the
		# action
		if block_given?
			self.log.debug "Yielding to passed block"
			rval = yield( meth, txn, *args )
		else
			self.log.debug "Applet action arity: %d; args = %p" %
				[ meth.arity, args ]

			# Invoke the action with the right number of arguments.
			if meth.arity < 0
				rval = meth.call( txn, *args )
			elsif meth.arity >= 1
				args.unshift( txn )
				until args.length >= meth.arity do args << nil end
				rval = meth.call( *(args[0, meth.arity]) )
			else
				raise Arrow::AppletError,
					"Malformed action: Must accept at least a transaction argument"
			end
		end

		# Calculate CPU times
		runtimes = Process.times
		@run_count += 1
		@total_utime += utime = (runtimes.utime - starttimes.utime)
		@total_stime += stime = (runtimes.stime - starttimes.stime)
		self.log.info \
			"[PID %d] Runcount: %d, User: %0.2f/%0.2f, System: %0.2f/%0.2f" %
			[ Process.pid, @run_count, utime, @total_utime, stime, @total_stime ]

		return rval
	end


	### Given an +action+ name (or +nil+ for the default action), return a
	### Method for the action method which should be invoked on the specified +txn+.
	def lookup_action_method( txn, action, *args )
		self.log.debug "Mapping %s( %p ) to an action" % [ action, args ]

		# Look up the Method object that needs to be called
		if (( match = @actions_regexp.match(action.to_s) ))
			action = match.captures[0]
			action.untaint
			self.log.debug "Matched action = #{action}"
		else
			self.log.info "Couldn't find specified action %p. "\
				"Defaulting to the 'action_missing' action." % action
			args.unshift( action )
			action = "action_missing"
		end

		return self.method( "#{action}_action" ), *args
	end



	### Wrapper method for a delegation (chained) request.
	def delegate( txn, chain, *args )
		yield( chain )
	end


	### Returns +true+ if the receiver has a #delegate method that is inherited
	### from somewhere other than the base Arrow::Applet class.
	def delegable?
		return self.method(:delegate).to_s !~ /\(Arrow::Applet\)/
	end
	alias_method :chainable?, :delegable?


	### The action invoked if the specified action is not explicitly
	### defined. The default implementation will look for a template with the
	### same key as the action, and if found, will load that and return it.
	def action_missing_action( txn, raction, *args )
		self.log.debug "In action_missing_action with: raction = %p, args = %p" %
			[ raction, args ]

		if raction && @signature.templates.key?( raction.to_s.intern )
			self.log.debug "Using template sender default action for %s" % raction
			txn.vargs = self.make_validator( raction, txn )
			tmpl = self.load_template( raction.intern )
			tmpl.txn = txn
			return tmpl
		else
			raise Arrow::AppletError, "No such action '%s' in %s" %
				[ raction, self.signature.name ]
		end
	end


	### Return a human-readable String representing the applet.
	def inspect
		"<%s:0x%08x: %s [%s/%s]>" % [
			self.class.name,
			self.object_id * 2,
			@signature.name,
			@signature.version,
			@signature.maintainer
		]
	end


	### Returns the average number of seconds (user + system) per run.
	def average_usage
		return 0.0 if @run_count.zero?
		(@total_utime + @total_stime) / @run_count.to_f
	end


	#########
	protected
	#########

	### Run an action with a duped transaction (e.g., from another action)
	def subrun( action, txn, *args )
		action, txn = txn, action if action.is_a?( Arrow::Transaction )
		self.log.debug "Running subordinate action '%s' from '%s'" %
			[ action, caller[0] ]

		# Make sure the transaction has stuff loaded. This is necessary when
		# #subrun is called without going through #run first (e.g., via 
		# #delegate)
		if txn.vargs.nil?
			self.prep_transaction( txn )
			txn.vargs = self.make_validator( action, txn )
		end

		meth, *args = self.lookup_action_method( txn, action, *args )
		return meth.call( txn, *args )
	end


	### Prepares the transaction (+txn+) for applet execution. By default, this
	### method sets the content type of the response to 'text/html' and turns off
	### buffering for the header.
	def prep_transaction( txn )
		txn.request.content_type = "text/html"
		txn.request.sync_header = true
	end


	### Load and return the template associated with the given +key+ according
	### to the applet's signature. Returns +nil+ if no such template exists.
	def load_template( key )
		
		tname = @signature.templates[key] or
			raise Arrow::AppletError, 
				"No such template %p defined in the signature for %s (%s)" %
				[ key, self.signature.name, self.class.filename ]

		tname.untaint

		return @template_factory.get_template( tname )
	end
	alias_method :template, :load_template


	### Return the validator profile that corresponds to the +action+ which
	### will be executed by the specified +txn+. Returns the __default__
	### profile if no more-specific one is available.
	def get_validator_profile_for_action( action, txn )
		if action.to_s =~ /^(\w+)$/
			action = $1
			action.untaint
		else
			self.log.warning "Invalid action '#{action.inspect}'"
			action = :__default__
		end
		
		# Look up the profile for the applet or the default one
		profile = @signature.validator_profiles[ action.to_sym ] ||
			@signature.validator_profiles[ :__default__ ]

		if profile.nil?
			self.log.warning "No validator for #{action}, and no __default__. "\
				"Returning nil validator."
			return nil
		end

		return profile
	end
	

	### Create a FormValidator object for the specified +action+ which has
	### been given the arguments from the given +txn+.
	def make_validator( action, txn )
		profile = self.get_validator_profile_for_action( action, txn ) or
			return nil

		# Create a new validator object, map the request args into a regular
		# hash, and then send them to the validaator with the applicable profile
		self.log.debug "Creating form validator for profile: %p" % profile

		params = {}

		# Only try to parse form parameters if there's a form
		if txn.form_request?
			txn.request.paramtable.each do |key,val|
				# Multi-valued vs. single params
				params[key] = val.to_a.length > 1 ? val.to_a : val.to_s
			end
		end
		validator = Arrow::FormValidator.new( profile, params )

		self.log.debug "Validator: %p" % validator
		return validator
	end

end # class Arrow::Applet

