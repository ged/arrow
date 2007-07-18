#!/usr/bin/env ruby -w


TestProfile = {
	:required                => [ :required ],
	:optional                => %w{optional},
	:constraints             => {
		:number		=> /^(\d+)$/,
		:alpha		=> /^(\w+)$/,
	},
	:untaint_all_constraints => true
}
