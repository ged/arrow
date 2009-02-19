#!/usr/bin/ruby

require 'arrow/applet'
require 'arrow/acceptparam'

# :nodoc:
module Arrow

	# A collection of functions for abstracting authentication and authorization
	# away from Arrow::Applets. Applets which include this module should provide
	# implementations of at least the #get_authenticated_user method, and may
	# provide implementations of other methods to tailor the authentication for
	# their particular applet.
	# 
	# == Customization API
	# 
	# [[#get_authenticated_user]]
	#   Override this method to provide the particulars of your authentication
	#   system. The method is given the Arrow::Transaction object that wraps the
	#   incoming request, and should return whatever kind of "user" object they
	#   wish to use. The only requirement for a user object as far as this mixin 
	#   is concerned is that it must have a #to_s method, so even a simple username
	#   in a String will suffice. If no authorization is possible, return nil, which
	#   will cause the #login_action to be invoked.
	# [[#user_is_authorized]]
	#   Override this method to provide authorization checks of an authenticated user
	#   (the one returned from #get_authenticated_user) against the incoming request.
	#   If the user is authorized to run the action, return +true+, else return 
	#   +false+. Failed authorization will cause the #deny_access_action to be
	#   invoked.
	# [[#login_action]]
	#   Override this method if you wish to customize the login process. By default,
	#   this returns a response that prompts the client using Basic HTTP 
	#   authentication.
	# [[#logout_action]]
	#   Override this method if you wish to customize the logout process. By default,
	#   this declines the request, which will tell Apache to try to handle the 
	#   request itself.
	# [[#deny_access_action]]
	#   Override this method if you wish to customize what happens when the client
	#   sends a request for a resource they are not authorized to interact with. By
	#   default, this method returns a simple HTTP FORBIDDEN response.
	#
	# == Subversion Id
	#
	#  $Id$
	# 
	# == Authors
	# 
	# * Michael Granger <ged@FaerieMUD.org>
	# 
	# :include: LICENSE
	#
	#--
	#
	# Please see the file LICENSE in the BASE directory for licensing details.
	#
	module AppletAuthentication
		
		### Default AppletAuthentication API: provides login functionality for actions that
		### require authorization; override this to provide a login form. By default, this
		### just returns an HTTP UNAUTHORIZED response.
		def login_action( txn, *args )
			self.log.info "Prompting the client for authentication"
			# :TODO: This really needs to set the WWW-Authenticate header...
			return Apache::HTTP_UNAUTHORIZED
		end
		

		### Default AppletAuthentication API: provides login functionality for actions that
		### require authorization; override this to customize the logout process. By default, this
		### just returns +nil+, which will decline the request.
		def logout_action( txn, *args )
			self.log.info "No logout action provided, passing the request off to the server"
			return Apache::DECLINED
		end
		

		### Default AppletAuthentication API: provides a hook for applets which have some
		### actions which require authorization to run; override this to provide a "Forbidden"
		### page. By default, this just returns an HTTP FORBIDDEN response.
		def deny_access_action( txn, *args )
			self.log.error "Unauthorized request for %s" % [ txn.uri ]
			return Apache::FORBIDDEN
		end
		

		#########
		protected
		#########

		### Check to see that the user is authenticated. If not attempt to
		### authenticate them via a form. If they are authenticated, or become
		### authenticated after the form action, call the supplied block with the
		### authenticated user.
		def with_authentication( txn, *args )
			self.log.debug "wrapping a block in authentication"

			# If the user doesn't have a session user, go to the login form.
			if user = self.get_authenticated_user( txn )
				return yield( user )
			else
				self.log.warning "Authentication failed from %s for %s" %
					[ txn.connection.remote_host, txn.the_request ]
				return self.subrun( :login, txn, *args )
			end
		end


		### Wrap a block in authorization. If the given +user+ has all of the
		### necessary permissions to run the given +applet_chain+ (an Array of
		### Arrow::AppRegistry::ChainLink structs), call the provided block. 
		### Otherwise run the 'deny_access' action and return the result. 
		def with_authorization( txn, *args )
			self.with_authentication( txn ) do |user|
				self.log.debug "Checking permissions of '%s' to execute %s" % [ user, txn.uri ]

				if self.user_is_authorized( user, txn, *args )
					return yield
				else
					self.log.warning "Access denied to %s for %s" % [ user, txn.the_request ]
					return self.subrun( :deny_access, txn )
				end
			end
		end


		### Default AppletAuthentication API: return a "user" object if the specified +txn+ 
		### object provides authentication. Applets wishing to authenticate uses should 
		### provide an overriding implementation of this method. The base implementation
		### always returns +nil+.
		def get_authenticated_user( txn )
			self.log.notice "No implementation of get_authenticated_user for %s" %
				[ self.class.signature.name ]
			return nil
		end
		
		
		### Default AppletAuthentication API: returns true if the specified +user+ is
		### authorized to run the applet. Applets wishing to authorize users should
		### provide an overriding implementation of this method. The base implementation
		### always returns +false+.
		def user_is_authorized( user, txn, *args )
			self.log.notice "No implementation of user_is_authorized for %s" %
				[ self.class.signature.name ]
			return false
		end
		
		
	end # module AppletAuthentication
	
	
	### Add access-control to all actions and then allow them to be removed on a per-action 
	### basis via a directive.
	module AccessControls
		include Arrow::AppletAuthentication
		
		# Actions which don't go through access control
		UNAUTHENTICATED_ACTIONS = [
			:deny_access, :login, :logout
		].freeze
		

		### Methods to add to including classes
		module ClassMethods
			### Allow declaration of actions which don't require authentication -- all other 
			### methods are authenticated by default
			def unauthenticated_actions( *actions )
				@unauthenticated_actions.push( *actions )
				return @unauthenticated_actions
			end
			alias :unauthenticated_action :unauthenticated_actions
			
		end
		

		### Inclusion callback
		def self::included( mod )
			Arrow::Logger[ self ].debug "Adding declarative method to %p" % [ mod ]
			mod.instance_variable_set( :@unauthenticated_actions, UNAUTHENTICATED_ACTIONS.dup )
			mod.extend( ClassMethods )
			super
		end
		

		### Overridden to map the +action+ to the authorization action's method if
		### +action+ isn't one of the ones that's defined as unauthenticated.
		def find_action_method( txn, action=nil, *args )
			if self.class.unauthenticated_actions.include?( action )
				self.log.debug "Supering to unauthenticated action %p" % [ action ]
				super
			else
				self.log.debug "Action %p wasn't marked as unauthenticated; checking authorization." %
					[ action ]
				with_authorization( txn, action, *args ) do
					super
				end
			end
		end
		
		
		### Delegate to applets further on in the chain only if the user is authorized.
		def delegate( txn, chain, *args )
			self.log.debug "Delegating to chain: %p" % [ chain ]

			with_authorization( txn, chain ) do
				yield( chain )
			end
		end

	end # AccessControls

	
end # module Arrow


