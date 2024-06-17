# ByteCodeWriter.coffee

fs = require("fs")
{  undef, defined, notdefined, isString,
	assert, croak, range, indented, undented,
	} = require('./vllu.js');

# ---------------------------------------------------------------------------

class ByteCodeWriter

	constructor: (@ast, hOptions={}) ->

		assert (@ast.type == 'grammar'), "not a grammar"
		assert (@ast.rules.length > 0), "no rules"
		@name = @ast.rules[0].name
		@hRules = {}
		@hCounts = {}
		@lOpcodes = undef
		@detailed = hOptions.detailed

	# ..........................................................

	getOpInfo: (op) ->

		switch op
			when 35 then return 'PUSH_EMPTY_STRING'
			when 5 then return 'PUSH_CUR_POS'
			when 1 then return 'PUSH_UNDEFINED'
			when 2 then return 'PUSH_NULL'
			when 3 then return 'PUSH_FAILED'
			when 4 then return 'PUSH_EMPTY_ARRAY'
			when 6 then return 'POP'
			when 7 then return 'POP_CUR_POS'
			when 8
				return {
					name: 'POP_N'
					lArgInfo: ['/number']
					}
			when 9 then return 'NIP'
			when 10 then return 'APPEND'
			when 11
				return {
					name: 'WRAP'
					lArgInfo: [undef]
					}
			when 12 then return 'TEXT'
			when 36
				return {
					name: 'PLUCK'
					lArgInfo: [undef, undef, undef, 'p']
					}
			when 14
				return {
					name: 'IF_ERROR'
					lArgInfo: ['OK/block','FAIL/block']
					}
			when 15
				return {
					name: 'IF_NOT_ERROR'
					lArgInfo: ['OK/block','FAIL/block']
					}
			when 17
				return {
					name: 'MATCH_ANY'
					lArgInfo: ['OK/block','FAIL/block']
					}
			when 18
				return {
					name: 'MATCH_STRING'
					lArgInfo: ['/literal', 'OK/block', 'FAIL/block']
					}
			when 20
				return {
					name: 'MATCH_CHAR_CLASS'
					lArgInfo: ['/class']
					}
			when 21
				return {
					name: 'ACCEPT_N'
					lArgInfo: ['/number']
					}
			when 22
				return {
					name: 'ACCEPT_STRING'
					lArgInfo: ['/literal']
					}
			when 23
				return {
					name: 'FAIL'
					lArgInfo: ['/expectation']
					}
			when 27
				return {
					name: 'RULE'
					lArgInfo: ['/rule']
					}
			else
				return undefined

	# ..........................................................

	argStr: (arg, infoStr) ->

		if (infoStr == undef)
			return arg.toString()

		[label, type] = infoStr.split('/')

		switch type

			when 'rule'
				if (typeof(arg) == 'number') && (arg < @ast.rules.length)
					result = "<#{@ast.rules[arg].name}>"
				else
					result = "<UNKNOWN RULE #{arg}>"

			when 'literal'
				result = "'#{@ast.literals[arg]}'"

			when 'number'
				result = arg.toString()

			when 'expectation'
				hExpect = @ast.expectations[arg]
				{type, value} = hExpect
				switch type
					when 'literal'
						result = "\"#{value}\""
					when 'class'
						result = "[..]"
					when 'any'
						result = '.'
					else
						croak "Unknown expectation type: #{type}"
			when 'block'
				if label
					result = "#{label}:#{arg}"
				else
					result = "BLOCK: #{arg}"

			when 'class'
				if label
					result = "#{label}:[#{arg}]"
				else
					result = "CLASS: #{arg}"

			else
				croak "argStr(): unknown type #{type}"

		if @detailed
			return "(#{arg}) #{result}"
		else
			return result

	# ..........................................................

	opStr: (lOpcodes) ->

		lLines = []
		pos = 0
		nOpcodes = lOpcodes.length
		while (pos < nOpcodes)
			op = lOpcodes[pos]
			pos += 1

			hInfo = @getOpInfo(op)
			if notdefined(hInfo)
				lLines.push "OPCODE #{op}"
				continue

			if isString(hInfo)
				hInfo = {name: hInfo}
			{name, lArgInfo} = hInfo
			if notdefined(lArgInfo)
				lArgInfo = []
			numArgs = lArgInfo.length

			lArgs = lOpcodes.slice(pos, pos + numArgs)
			pos += numArgs
			lArgDesc = lArgs.map (arg,i) => @argStr(arg, lArgInfo[i])

			if @detailed
				lLines.push "(#{op}) #{name}#{' ' + lArgDesc.join(' ')}"
			else
				lLines.push "#{name}#{' ' + lArgDesc.join(' ')}"

			for arg,i in lArgs
				infoStr = lArgInfo[i]
				if notdefined(infoStr)
					continue
				if infoStr.includes('/')
					[label, type] = infoStr.split('/')
					if (type == 'block')
						lLines.push indented("[#{label}]")

						# --- NOTE: arg is the length of the block in bytes
						lSubOps = lOpcodes.slice(pos, pos+arg)
						pos += arg
						lLines.push indented(@opStr(lSubOps), 2)

		return lLines.join("\n")

	# ..........................................................

	add: (ruleName, lOpcodes) ->

		assert (typeof ruleName == 'string'), "not a string"
		assert Array.isArray(lOpcodes), "not an array"
		assert !@hRules[ruleName], "rule #{ruleName} already defined"
		@hRules[ruleName] = lOpcodes
		return

	# ..........................................................

	write: () ->
		lParts = []
		for ruleName in Object.keys(@hRules)
			lParts.push "#{ruleName}:"
			lOpcodes = @hRules[ruleName]
			lParts.push indented(@opStr(lOpcodes))
			lParts.push ''
		fileName = "./#{@name}.bytecodes.txt"
		console.log "Writing bytecodes to #{fileName}"
		fs.writeFileSync(fileName, lParts.join("\n"))
		return

# --------------------------------------------------------------------------

module.exports = {
	ByteCodeWriter,
	}
