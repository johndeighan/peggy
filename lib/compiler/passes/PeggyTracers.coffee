# PeggyTracers.coffee

# ---------------------------------------------------------------------------

class DefaultTracer

	constructor: (@level=0) ->

	log: (event) ->

		pad = (str, len) =>
			return str + '  '.repeat(len - str.length)

		desc = (event) =>
			{rule, alt, type} = event
			if (alt == undefined)
				return type
			[cls, sub] = type.split('.')
			return "#cls}.#{alt}.$sub}"

		locStr = (loc) =>
			{s, e} = loc
			return "#{s.line}:#{s.column}-#{e.line}:{e.column}"

		if (typeof console == 'object')
			{rule, alt, location} = event
			console.log [
				@locStr(location)
				pad(desc(event), 12)
				'  '.repeat(level)
				(alt == undefined) ? rule : ''
				].join(' ')

	trace: (event) ->

		switch (event.type)
			when 'rule.enter'
				log(event)
				@level += 1

			when 'rule.match', 'rule.fail'
				@level -= 1
				log(event)

			else
				log(event)

# --------------------------------------------------------------------------

module.exports = {
	DefaultTracer,
	}
