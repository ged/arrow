#!/usr/bin/ruby
# 
# This file contains the Arrow::Applet class, which is an abstract base
# class for Arrow applets.
# 
# == Synopsis
#
#    require 'arrow/monitor'
#    require 'arrow/monitor/subjects'
#    require 'arrow/applet'
#
#    class MyApplet < Arrow::Applet
#        Signature = {
#            :name               => 'My Applet',
#            :description        => 
#                'Displays a block of whatever character is passed as argument',
#            :maintainer         => 'Michael Granger <mgranger@rubycrafters.com>',
#            :version            => '1.01',
#            :uri                => 'myapplet',
#            :defaultAction      => 'form',
#            :templates          => {
#                :main => 'main.templ',
#            },
#            :validatorProfiles  => {
#                :__default__      => {
#                   :optional       => [:char],
#                   :constraints    => {
#                       :char => {
#                           :name       => "single non-whitespace character",
#                           :constraint => /^\S$/,
#                       },
#                   },
#                },
#            },
#            :monitors           => {
#                :averageExecutionTimer => {
#                    :description =>
#                        "Average execution time of each applet method.",
#                    :type => AverageTimerTable,
#                },
#                :cumulativeRuntime => {
#                    :description =>
#                        "Total time used by this applet.",
#                    :type => TotalTimer,
#                }
#            }
#        }
#
#		 # Define the 'display' action
#        action( 'display' ) {|txn|
#            Monitor[self].cumulativeRuntime.time do
#                char = txn.vargs[:char] || 'x'
#                char_page = self.make_character_page( char )
#                templ = txn.templates[:main]
#                templ.char_page = char_page
#
#                return templ
#            end
#        }
#
#
#        # Define the 'form' action -- display a form that can be used to set
#        # the character the block is composed of. Save the returned proxy so
#        # the related signature values can be set.
#        formaction = action( :form ) {|txn|
#            Monitor[self].cumulativeRuntime.time do
#                templ = txn.templates[:form]
#                templ.txn = txn
#                return templ
#            end
#        }
#        formaction.template = "form.tmpl"
#
#        def make_character_page( char )
#            Monitor[self].averageExecutionTimer.time( :make_character_page ) do
#                page = (char * 80)
#            end
#        end
#
#    end
# 
# == Rcsid
# 
# $Id: applet.rb,v 1.14 2004/02/14 23:15:03 deveiant Exp $
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

require 'formvalidator'
require 'forwardable'

require 'arrow/mixins'
require 'arrow/exceptions'
require 'arrow/object'

### Add some Hash-ish methods for convenient access to FormValidator#valid.
class FormValidator
	unless method_defined?( :[] )
		extend Forwardable
		def_delegators :@form, *(Hash::instance_methods(false) - [:[], :[]=])

		def []( key )
			@form[ key.to_s ]
		end

		def []=( key, val )
			@form[ key.to_s ] = val
		end
	end
end


module Arrow

### An abstract base class for Arrow applets. Provides execution logic,
### argument-parsing/untainting/validation, and templating.
class Applet < Arrow::Object

	# CVS version tag
	Version = /([\d\.]+)/.match( %q{$Revision: 1.14 $} )[1]

	# CVS id tag
	Rcsid = %q$Id: applet.rb,v 1.14 2004/02/14 23:15:03 deveiant Exp $

	### Applet signature struct. The fields are as follows:
	### [<b>uri</b>]
	###	  The URI of this applet relative to the base URL for the application.
	### [<b>name</b>]
	###	  The name of the applet; used for introspection and reports.
	### [<b>description</b>]
	###	  The description of the applet; used for introspection.
	### [<b>maintainer</b>]
	###	  The name of the maintainer for reports and introspection.
	### [<b>version</b>]
	###	  The version or revision number of the applet, which can be
	###	  any object that has a #to_s method.
	### [<b>defaultAction</b>]
	###	  The action that will be run if no action is specified.
	### [<b>templates</b>]
	###	  A hash of templates used by the applet. The keys are Symbol
	###	  identifiers which will be used for lookup, and the values are the
	###	  paths to template files.
	### [<b>validatorProfiles</b>]
	###	  A hash containing profiles for the built in form validator, one
	###	  per action. See the documentation for FormValidator for the format
	###	  of each profile hash.
	### [<b>monitors</b>]
	###	  A hash of monitor objects that can be used for introspection,
	###	  debugging, profiling, and tuning the applet. The keys are
	###	  symbol identifiers which will be used later when using the
	###	  configured monitors. See Arrow::Monitor for possible values.
	SignatureStruct = Struct::new( :name, :description, :uri, :maintainer,
		:version, :config, :defaultAction, :templates, :validatorProfiles,
		:monitors )

	# Default-generators for Signatures which are missing one or more of the
	# optional pairs.
	SignatureStructDefaults = {
		:name				=> proc {|rawsig, klass| klass.name},
		:description		=> "(none)",
		:uri				=> nil,
		:maintainer			=> nil, # Workaround for RDoc
		:version			=> nil, # Wordaround for RDoc
		:defaultAction		=> '_default',
		:config				=> {},
		:templates			=> {},
		:validatorProfiles	=> {
			:__default__		=> {
				:optional			=> [:action],
				:constraints		=> {
					:action => /^\w+$/,
				},
			},
		},
		:monitors			=> {},
	}

	SignatureStructDefaults[:maintainer] = proc {|rawsig, klass|
		if defined?( Apache )
			Apache.request.server.admin
		else
			""
		end
	}

	SignatureStructDefaults[:version] = proc {|rawsig, klass|
		if klass.const_defined?( :Version )
			return klass.const_get( :Version )
		elsif klass.const_defined?( :Revision )
			return klass.const_get( :Revision )
		elsif klass.const_defined?( :Rcsid )
			return klass.const_get( :Rcsid )
		else
			begin
				File::stat( klass.sourcefile ).mtime
			rescue
			end
		end
	}


	### Proxy into the Applet's signature for a given action.
	class SigProxy

		### Create a new proxy into the given +klass+'s Signature for the
		### specified +action_name+.
		def initialize( action_name, klass )
			@action_name = action_name.intern
			@signature = klass.signature
			@signature[:templates] ||= {}
			@signature[:validatorProfiles] ||= {}
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
		def validatorProfile
			@signature[:validatorProfiles][@action_name]
		end


		### Set the validator profile associated with the same name as the
		### proxied action to +hash+.
		def validatorProfile=( hash )
			@signature[:validatorProfiles][@action_name] = hash
		end

	end # class SigProxy


	# The array of loaded applet classes (derivatives)
	@derivatives = []


	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	class << self

		# The Array of loaded applet classes (derivatives)
		attr_reader :derivatives


		### Inheritance callback: register any derivative classes so they can be
		### looked up later.
		def inherited( klass )
			Arrow::Logger[self].debug "#{self.name} inherited by #{klass.name}"

			if defined?( @derivatives )
				@derivatives.push( klass )
				super
			else
				Arrow::Applet::inherited( klass )
			end
		end


		### Method definition callback: Check newly-defined action methods for
		### appropriate arity.
		def method_added( sym )
			if /^(\w+)_action$/.match( sym.to_s ) &&
					self.instance_method( sym ).arity.zero?
				raise ScriptError, "Inappropriate arity for #{sym}", caller(1)
			end
		end


		### Load any applet classes in the given file and return them.
		def load( filename )
			oldderivatives = @derivatives.dup
			@derivatives.clear

			rval = Kernel::load( filename, true )
			Arrow::Logger[self].debug "Kernel::load returned: %p" % rval

			newderivatives = @derivatives.dup
			return newderivatives
		ensure
			Arrow::Logger[self].debug "Merging applet lists"
			@derivatives |= oldderivatives
		end


		### Get the applet's signature (an
		### Arrow::Applet::SignatureStruct object).
		def signature
			@signature ||= makeSignature
		end


		### Returns +true+ if the applet class has a signature.
		def signature?
			!self.signature.nil?
		end


		### Signature lookup: look for either a constant or an instance
		### variable of the class that contains the raw signature hash, and
		### convert it to an Arrow::Applet::SignatureStruct object.
		def makeSignature
			rawsig = nil
			if self.instance_variables.include?( "@signature" )
				rawsig = self.instance_variable_get( :@signature )
			elsif self.constants.include?( "Signature" )
				rawsig = self.const_get( :Signature )
			elsif self.constants.include?( "SIGNATURE" )
				rawsig = self.const_get( :SIGNATURE )
			else
				return nil
			end

			# Backward-compatibility: Rewrite the 'vargs' member as
			# 'validatorProfiles' if 'vargs' exists and 'validatorProfiles'
			# doesn't. 'vargs' member will be deleted regardless.
			rawsig[ :validatorProfiles ] ||= rawsig.delete( :vargs ) if
				rawsig.key?( :vargs )

			# If the superclass has a signature, inherit values from it for
			# pairs that are missing.
			if self.superclass < Arrow::Applet && self.superclass.signature?
				self.superclass.signature.each_pair {|member,value|
					rawsig[ member ] = value if rawsig[member].nil?
				}
			end

			# Apply sensible defaults for members that aren't defined
			SignatureStructDefaults.each {|key,val|
				next if rawsig[ key ]
				case val
				when Proc, Method
					rawsig[ key ] = val.call( rawsig, self )
					Arrow::Logger[self].debug "Defaulted %s to %p via Proc/Method" % [ key, rawsig[key] ]
				when Numeric, NilClass, FalseClass, TrueClass
					rawsig[ key ] = val
					Arrow::Logger[self].debug "Defaulted %s to %p via Immediate" % [ key, rawsig[key] ]
				else
					rawsig[ key ] = val.dup
					Arrow::Logger[self].debug "Defaulted %s to %p via Literal" % [ key, rawsig[key] ]
				end
			}

			# Signature = Struct::new( :name, :description, :uri, :maintainer,
			# 	:version, :config, :defaultAction, :templates, :validatorArgs,
			# 	:monitors )
			members = SignatureStruct::members.collect {|m| m.intern}
			return SignatureStruct::new( *rawsig[*members] )
		end


		### Define an action for the applet. Transactions which include the
		### specified +name+ as the first directory of the uri after the
		### applet's name will be passed to the given +block+. The return value
		### from this method is an Arrow::Applet::SigProxy which can be used to
		### set associated values in the applet's Signature; see the Synopsis in
		### lib/arrow/applet.rb for examples of how to use this.
		def action( name, &block )
			name = '_default' if name.to_s.empty?
			
			# Action must accept at least a transaction argument
			unless block.arity.nonzero?
				raise ScriptError,
					"Malformed action #{name}: must accept at least one argument"
			end

			methodName = "#{name}_action"
			define_method( methodName, &block )
			SigProxy::new( name, self )
		end

	end # class << self


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################


	### Create a new Arrow::Applet object with the specified +config+
	### (an Arrow::Config object) and +templateFactory+ (an
	### Arrow::TemplateFactory object).
	def initialize( config, templateFactory )
		@config			 = config
		@templateFactory = templateFactory
		@signature		 = self.class.signature
		@runCount		 = 0
		@totalUtime		 = 0
		@totalStime		 = 0

		# Make a regexp out of all public <something>_action methods
		@actions		= self.public_methods( false ).
			select {|meth| /^(\w+)_action$/ =~ meth }.
			collect {|meth| meth.gsub(/_action/, '') }
		@actionsRe	= Regexp::new( "^(" + actions.join( '|' ) + ")$" )
	end


	######
	public
	######

	# The Arrow::Config object which contains the system's configuration.
	attr_accessor :config

	# The Struct that contains the configuration values for this applet
	attr_reader :signature

	# The number of times this particular applet object has been run
	attr_reader :runCount

	# The number of user seconds spent in this applet's #run method.
	attr_reader :totalUtime

	# The number of system seconds spent in this applet's #run method.
	attr_reader :totalStime

	# The Arrow::TemplateFactory object used to load templates for the applet.
	attr_reader :templateFactory

	# The list of all valid actions on the applet
	attr_reader :actions


	### Run the specified +action+ for the given +txn+ and the specified
	### +args+.
	def run( txn, action=nil, *args )
		starttimes = Process::times

		# Do any initial preparation of the transaction that can be factored out
		# of all the actions.
		self.prepTransaction( txn )

		# Look up the Method object that needs to be called
		if ( !action.nil? && (match = @actionsRe.match( action )) )
			action = match.captures[0]
			action.untaint
			self.log.debug "Matched action = #{action}"
		else
			self.log.info "Couldn't find specified action %p. "\
				"Defaulting to the 'action_missing' action." % action
			args.unshift( action )
			action = "action_missing"
		end
		meth = self.method( "#{action}_action" )

		# Make a FormValidator object and add it to the transaction
		txn.vargs = self.makeValidator( action, txn )

		# Now either pass control to the block, if given, or invoke the
		# action
		if block_given?
			self.log.debug "Yielding to passed block"
			yield( meth, txn, *args )
		else
			self.log.debug "Applet action arity: %d; args = %p" %
				[ meth.arity, args ]

			# Invoke the action with the right number of arguments.
			if meth.arity < 0
				rval = meth.call( txn, *args )
			elsif meth.arity >= 1
				args.unshift( txn )
				rval = meth.call( *(args[0, meth.arity]) )
			else
				raise AppletError,
					"Malformed action: Must accept at least a transaction argument"
			end
		end

		# Calculate CPU times
		runtimes = Process::times
		@runCount += 1
		@totalUtime += utime = (runtimes.utime - starttimes.utime)
		@totalStime += stime = (runtimes.stime - starttimes.stime)
		Arrow::Logger[Arrow::Applet].debug \
			"[PID %d] Runcount: %d, User: %0.2f, System: %0.2f" %
			[ Process::pid, @runCount, utime, stime ]

		return rval
	end


	### Wrapper method for a delegation (chained) request.
	#def delegate( txn, *args )
	#	yield( txn, *args )
	#end


	### The action invoked if the specified action is not explicitly
	### defined. The default implementation will 
	def action_missing_action( txn, raction, *args )
		self.log.debug "In action_missing_action with: raction = %p, args = %p" %
			[ raction, args ]

		if raction && txn.templates.key?( raction.intern )
			self.log.debug "Using template sender default action for %s" % raction
			txn.vargs = self.makeValidator( raction, txn )
			tmpl = txn.templates[ raction.intern ]
			tmpl.txn = txn
			return tmpl
		end

		default = @signature.defaultAction
		unless default == raction
			self.run( txn, default, *args )
		else
			raise AppletError, "Missing default handler '#{default}'"
		end
	end


	### Return a human-readable String representing the applet.
	def inspect
		"<%s:0x%08x: %s [%s/%s] at /%s>" % [
			self.class.name,
			self.object_id * 2,
			@signature.name,
			@signature.version,
			@signature.maintainer,
			@signature.uri,
		]
	end


	### Returns the average number of seconds (user + system) per run.
	def averageUsage
		return 0.0 if @runCount.zero?
		(@totalUtime + @totalStime) / @runCount.to_f
	end


	#########
	protected
	#########

	### Prepares the transaction (+txn+) for applet execution. By default, this
	### method sets the content type of the response to 'text/html', turns off
	### buffering for the header, and adds the applet's templates.
	def prepTransaction( txn )

		txn.request.content_type = "text/html"
		txn.request.sync_header = true

		# Load the applet's templates and add them to the transaction
		txn.templates = self.loadTemplates( @signature.templates )
	end


	### Load the templates specified in the given +hash+. The +hash+ should
	### be in the same form as the ':templates' key of the
	### Arrow::Applet::SignatureStruct specification. The returned hash
	### will be a duplicate of the original with the template paths replaced
	### with the corresponding template objects.
	def loadTemplates( hash )
		rhash = hash.dup
		self.log.debug "Loading applet templates: %p" % hash

		rhash.each_key {|key|
			self.log.debug "Loading template for '%p'" % key
			tname = rhash[key]
			tname.untaint
			rhash[ key ] = @templateFactory.getTemplate( tname )
		}

		return rhash
	end


	### Create a FormValidator object for the specified +action+ which has
	### been given the arguments from the given +txn+.
	def makeValidator( action, txn )
		# Look up the profile for the applet or the default one
		profile = @signature.validatorProfiles[ action.to_s.intern ] ||
			@signature.validatorProfiles[ :__default__ ]

		if profile.nil?
			self.log.debug "No validator for #{action}, and no __default__. "\
				"Returning nil validator."
			return nil
		end

		self.log.debug "Creating form validator for profile: %p" % profile
		validator = FormValidator::new
		params = {}
		txn.request.paramtable.each {|key,val|
			params[key] = val.to_a.length > 1 ? val.to_a : val.to_s
		}
		validator.validate( params, profile )

		self.log.debug "Validator: %p" % validator
		return validator
	end

end # class Applet
end # module Arrow

