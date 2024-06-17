# OpDumper.coffee

fs = require("fs")
{  undef, defined, notdefined, isString,
	assert, croak, range, indented, undented,
	} = require('./vllu.js');

# --------------------------------------------------------------------------

class OpDumper

	constructor: () ->

		@level = 0

	incLevel: () -> @level += 1
	decLevel: () -> @level -= 1

	out: (str) ->
		console.log "  ".repeat(@level) + str

	outBC: (lByteCodes) ->

		@out 'OPCODES:'
		@out lByteCodes.map((x) => x.toString()).join(' ');
		return

# --------------------------------------------------------------------------

module.exports = {
	OpDumper
	}

