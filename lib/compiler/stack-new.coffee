# stack.coffee

import {SourceNode} from "source-map-generator"
import GrammarLocation from "../grammar-location.js"

undef = undefined

# ===========================================================================
# --- Utility class that helps generating code for C-like languages.

class Stack

	# --- Constructs the helper for tracking variable slots
	#     of the stack virtual machine

	# ------------------------------------------------------------------------
	# @param {PEG.LocationRange} location
	# @param {SourceArray} chunks
	# @param {string} [name]
	# @returns

	# --- A static method
	@sourceNode: (location, chunks, name) ->

		start = GrammarLocation.offsetStart(location)
		return new SourceNode(
			start.line,
			if start.column then start.column-1 else null,
			String(location.source),
			chunks,
			name
			)

	# ------------------------------------------------------------------------

	constructor: (ruleName, varName, type, bytecode) ->

		# --- Last used variable in the stack.
		@sp       = -1
		@maxSp    = -1       # --- maximum stack size
		@varName  = varName
		@ruleName = ruleName
		@type     = type
		@bytecode = bytecode

		# --- Map from stack index, to label targetting that index

		@labels = {}

		#  Stack of in-flight source mappings
		# @type {[SourceArray, number, PEG.LocationRange][]}

		@sourceMapStack = []

	# ------------------------------------------------------------------------
	# Returns name of the variable at the index i
	#
	# @param {number} i Index for which name must be generated
	# @return {string} Generated name
	#
	# @throws {RangeError} If `i < 0`, which means a stack underflow (there are more `pop`s than `push`es)

	name: (i) ->

		if (i < 0)
			throw new RangeError("""
				Rule '#{@ruleName}': The variable stack underflow:
				attempt to use a variable '#{@varName}<x>'
				at an index ${i}.\nBytecode: ${@bytecode}
				""")
		return @varName + i

	# ------------------------------------------------------------------------
	# Assigns `exprCode` to the new variable in the stack, returns generated code.
	# As the result, the size of a stack increases on 1.
	#
	# @param {string} exprCode Any expression code that must be assigned to the new variable in the stack
	# @return {string|SourceNode} Assignment code

	push: (exprCode) ->

		@sp += 1
		if (@sp > @maxSp)
			@maxSp = @sp

		label = @labels[@sp]
		code = [
			@name(@sp),
			" = ",
			exprCode,
			";"
			]
		if label
			if (@sourceMapStack.length > 0)
				sourceNode = Stack.sourceNode(
					label.location,
					code.splice(0, 2),
					label.label
					)
			{parts, location} = @sourceMapPopInternal()
			if (location.start.offset < label.location.end.offset)
				newLoc = {
					start: label.location.end,
					end: location.end,
					source: location.source,
					}
			else
				newLoc = location

			outerNode = Stack.sourceNode(
				newLoc,
				code.concat("\n")
				)
			@sourceMapStack.push([parts, parts.length + 1, location])
			return new SourceNode(
				null,
				null,
				label.location.source,
				[sourceNode, outerNode]
				)
		else
			return Stack.sourceNode(
				label.location,
				code.concat("\n")
				)
		return code.join("")

	# ------------------------------------------------------------------------
	#
	# Returns name or `n` names of the variable(s) from the top of the stack.
	#
	# @param {number} [n] Quantity of variables, which need to be removed from the stack
	# @returns {string[]|string} Generated name(s). If n is defined then it returns an
	#                            array of length `n`
	#
	# @throws {RangeError} If the stack underflow (there are more `pop`s than `push`es)

	pop: (n) =>

		if (n != undef)
			@sp -= n
			return Array.from({ length: n }, (v, i) => @name(@sp + 1 + i))
		pos = @sp
		@sp -= 1
		return @name(pos)

	# ------------------------------------------------------------------------
	# Returns name of the first free variable. The same as `index(0)`.
	#
	# @return {string} Generated name
	#
	# @throws {RangeError} If the stack is empty (there was no `push`'s yet)

	top: () ->
		return @name(@sp)

	# ------------------------------------------------------------------------
	# Returns name of the variable at index `i`.
	#
	# @param {number} i Index of the variable from top of the stack
	# @return {string} Generated name
	#
	# @throws {RangeError} If `i < 0` or more than the stack size

	index: (i) ->

		if (i < 0)
			throw new RangeError("""
				Rule '#{@ruleName}': The variable stack overflow:
				attempt to get a variable at a negative index #{i}.
				Bytecode: ${@bytecode}
				""")
		return @name(@sp - i)

	# ------------------------------------------------------------------------
	# Returns variable name that contains result (bottom of the stack).
	#
	# @return {string} Generated name
	#
	# @throws {RangeError} If the stack is empty (there was no `push`es yet)

	result: () ->

		if (@maxSp < 0)
			throw new RangeError("""
				Rule '${@ruleName}': The variable stack is empty,
				can't get the result.
				Bytecode: ${@bytecode}
				""")
		return @name(0)

	# ------------------------------------------------------------------------
	# Returns defines of all used variables.
	#
	# @return {string} Generated define variable expression with the type `@type`.
	#         If the stack is empty, returns empty string

	defines: () ->

		if (@maxSp < 0)
			return ""
		return @type \
				+ " " \
				+ Array.from({ length: @maxSp + 1 }, (v, i) => @name(i)).join(", ") \
				+ ";"

	# ------------------------------------------------------------------------
	# Checks that code in the `generateIf` and `generateElse` move the stack pointer in the same way.
	#
	# @template T
	# @param {number} pos Opcode number for error messages
	# @param {() => T} generateIf First function that works with this stack
	# @param {(() => T)|null} [generateElse] Second function that works with this stack
	# @return {T[]}
	#
	# @throws {Error} If `generateElse` is defined and the stack pointer moved differently in the
	#         `generateIf` and `generateElse`

	checkedIf: (pos, generateIf, generateElse) ->

		baseSp = @sp

		ifResult = generateIf()

		if (!generateElse)
			return [ifResult]

		thenSp = @sp

		@sp = baseSp
		elseResult = generateElse()

		if (thenSp != @sp)
			throw new Error("""
				Rule '#{@ruleName}', position #{pos}:
				Branches of a condition can't move the stack pointer differently
				(before: #{baseSp},
				after then: #{thenSp},
				after else: #{@sp},
				Bytecode: #{@bytecode}
				""")
		return [ifResult, elseResult]

	# ------------------------------------------------------------------------
	# Checks that code in the `generateBody` do not move stack pointer.
	#
	# @template T
	# @param {number} pos Opcode number for error messages
	# @param {() => T} generateBody Function that works with this stack
	# @return {T}
	#
	# @throws {Error} If `generateBody` moves the stack pointer
	#    (if it contains unbalanced `push`es and `pop`s)

	checkedLoop: (pos, generateBody) ->

		baseSp = @sp
		result = generateBody()
		if (baseSp != @sp)
			throw new Error("""
				Rule '#{@ruleName}', position #{pos}:
				Body of a loop can't move the stack pointer
				(before: #{baseSp}, after: #{@sp}).
				Bytecode: #{@bytecode}
				""")
		return result

	# ------------------------------------------------------------------------
	#
	# @param {SourceArray} parts
	# @param {PEG.LocationRange} location

	sourceMapPush: (parts, location) ->

		if (@sourceMapStack.length > 0)
			top = @sourceMapStack[@sourceMapStack.length - 1]

		# If the current top of stack starts at the same location as
		# the about to be pushed item, we should update its start location to
		# be past the new one. Otherwise any code it generates will
		# get allocated to the inner node.

		if (top[2].start.offset == location.start.offset) \
				&& (top[2].end.offset > location.end.offset)
			top[2] = {
				start: location.end,
				end: top[2].end,
				source: top[2].source,
				}
		@sourceMapStack.push([
			parts,
			parts.length,
			location,
			])
		return

	# ------------------------------------------------------------------------
	# @returns {{parts:SourceArray,location:PEG.LocationRange}}

	sourceMapPopInternal: () ->

		elt = @sourceMapStack.pop()
		if (!elt)
			throw new RangeError("""
				Rule '${@ruleName}':
				Attempting to pop an empty source map stack.
				Bytecode: ${@bytecode}
				""")

		[parts, index, location] = elt
		chunks = parts.splice(index).map(
			(chunk) =>
				if (chunk instanceof SourceNode)
					return chunk
				else
					return chunk + "\n"
				)

		if (chunks.length > 0)
			start = GrammarLocation.offsetStart(location)
			parts.push(new SourceNode(
				start.line,
				start.column - 1,
				String(location.source),
				chunks
				))
		return { parts, location }

	# ------------------------------------------------------------------------
	# @param {number} [offset]
	# @returns {[SourceArray, number, PEG.LocationRange]|undefined}

	sourceMapPop: (offset) ->

		{location} = @sourceMapPopInternal()
		stackLen = @sourceMapStack.length
		tos = @sourceMapStack[stackLen - 1]
		if (stackLen > 0) \
				&& (location.end.offset < tos[2].end.offset)
			{parts, location: outer} = @sourceMapPopInternal()
			if (outer.start.offset < location.end.offset)
				newLoc = {
					start: location.end,
					end: outer.end,
					source: outer.source,
					}
			else
				newLoc = outer

		@sourceMapStack.push([
			parts,
			parts.length + (offset || 0),
			newLoc,
			])
		return undef
