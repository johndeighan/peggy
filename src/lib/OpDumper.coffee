# OpDumper.coffee

fs = require("fs")
{  undef, defined, notdefined, isString,
	assert, croak, range, indented, undented,
	} = require('./vllu.js');

# --------------------------------------------------------------------------

class OpDumper

	constructor: (@name) ->

		@level = 0
		@lLines = []

	# ..........................................................

	incLevel: () -> @level += 1
	decLevel: () -> @level -= 1

	# ..........................................................

	out: (str) ->
		@lLines.push "  ".repeat(@level) + str
		return

	# ..........................................................

	outBC: (lByteCodes) ->

		@out 'OPCODES:'
		@out lByteCodes.map((x) => x.toString()).join(' ');
		return

	# ..........................................................

	write: () ->

		fileName = "./#{@name}.opcodes.txt"
		console.log "Writing opcodes to #{fileName}"
		fs.writeFileSync(fileName, lLines.join("\n"))
		return

# --------------------------------------------------------------------------

module.exports = {
	OpDumper
	}

