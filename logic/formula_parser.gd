extends RefCounted

## Recursive-descent parser for propositional formulas.
##
## Supported connectives: ~ & | -> <->
## Precedence (high to low): ~ > & > | > -> > <->, with -> and <-> right-associative.
## Atoms may be multi-character; whitespace is ignored between tokens.

const FormulaRes = preload("res://logic/formula.gd")
const ParseResultRes = preload("res://logic/parse_result.gd")

enum Tok { ATOM, NOT, AND, OR, IMPLIES, IFF, LPAREN, RPAREN, EOF }

## A lexical token with a 1-based source position.
class Token:
	var type: Tok
	var text: String
	var position: int

	func _init(p_type: Tok, p_text: String, p_position: int) -> void:
		type = p_type
		text = p_text
		position = p_position

const DELIMITERS := "~&|()-<>↔→"

var _text: String = ""
var _tokens: Array[Token] = []
var _index: int = 0
var _error: String = ""
var _error_position: int = 0

func _init(source: String) -> void:
	_text = source

## Parse the whole source string, returning a structured result.
func parse() -> ParseResultRes:
	_index = 0
	_error = ""
	_error_position = 0
	if not _tokenize():
		return _failure_result(_error, _error_position)

	_index = 0
	var parsed := _parse_iff()
	if parsed == null:
		return _failure_result(_error, _error_position)

	var trailing := _peek()
	if trailing.type != Tok.EOF:
		_set_error(
			"unexpected token %s at position %d; expected end of input"
			% [_token_desc(trailing), trailing.position],
			trailing.position
		)
		return _failure_result(_error, _error_position)

	return _success_result(parsed)

## Convert the source into tokens (including a final EOF token).
func _tokenize() -> bool:
	_tokens = []
	var length := _text.length()
	var index := 0
	while index < length:
		var character := _text.substr(index, 1)
		if _is_whitespace(character):
			index += 1
			continue

		var position := index + 1
		if character == "~":
			_tokens.append(Token.new(Tok.NOT, character, position))
			index += 1
		elif character == "&":
			_tokens.append(Token.new(Tok.AND, character, position))
			index += 1
		elif character == "|":
			_tokens.append(Token.new(Tok.OR, character, position))
			index += 1
		elif character == "(":
			_tokens.append(Token.new(Tok.LPAREN, character, position))
			index += 1
		elif character == ")":
			_tokens.append(Token.new(Tok.RPAREN, character, position))
			index += 1
		elif character == "-":
			if index + 1 < length and _text.substr(index + 1, 1) == ">":
				_tokens.append(Token.new(Tok.IMPLIES, "->", position))
				index += 2
			else:
				_set_error(
					"unexpected character '-' at position %d; implication is written '->'"
					% position,
					position
				)
				return false
		elif character == "<":
			if index + 2 < length and _text.substr(index, 3) == "<->":
				_tokens.append(Token.new(Tok.IFF, "<->", position))
				index += 3
			else:
				_set_error(
					"unexpected character '<' at position %d; biconditional is written '<->'"
					% position,
					position
				)
				return false
		elif character == "↔":
			_tokens.append(Token.new(Tok.IFF, "<->", position))
			index += 1
		elif character == "→":
			_tokens.append(Token.new(Tok.IMPLIES, "->", position))
			index += 1
		elif character == ">":
			_set_error(
				"unexpected character '>' at position %d; implication is written '->' and biconditional '<->'"
				% position,
				position
			)
			return false
		else:
			var start := index
			while index < length:
				var current := _text.substr(index, 1)
				if _is_whitespace(current) or DELIMITERS.contains(current):
					break
				index += 1
			if index == start:
				_set_error("unexpected character '%s' at position %d" % [character, position], position)
				return false
			_tokens.append(Token.new(Tok.ATOM, _text.substr(start, index - start), position))

	_tokens.append(Token.new(Tok.EOF, "", length + 1))
	return true

## Build a successful parse result without a class_name self-reference.
func _success_result(parsed: FormulaRes) -> ParseResultRes:
	var result := ParseResultRes.new()
	result.ok = true
	result.formula = parsed
	return result

## Build a failed parse result without a class_name self-reference.
func _failure_result(message: String, position: int) -> ParseResultRes:
	var result := ParseResultRes.new()
	result.ok = false
	result.error = message
	result.position = position
	return result

## iff := implication [ '<->' iff ]   (right-associative, lowest precedence)
func _parse_iff() -> FormulaRes:
	var left := _parse_implies()
	if left == null:
		return null
	if _match(Tok.IFF):
		var right := _parse_iff()
		if right == null:
			return null
		return FormulaRes.new(FormulaRes.Kind.IFF, "", left, right)
	return left

## implication := or [ '->' implication ]   (right-associative)
func _parse_implies() -> FormulaRes:
	var left := _parse_or()
	if left == null:
		return null
	if _match(Tok.IMPLIES):
		var right := _parse_implies()
		if right == null:
			return null
		return FormulaRes.new(FormulaRes.Kind.IMPLIES, "", left, right)
	return left

## or := and { '|' and }
func _parse_or() -> FormulaRes:
	var left := _parse_and()
	if left == null:
		return null
	while _match(Tok.OR):
		var right := _parse_and()
		if right == null:
			return null
		left = FormulaRes.new(FormulaRes.Kind.OR, "", left, right)
	return left

## and := unary { '&' unary }
func _parse_and() -> FormulaRes:
	var left := _parse_unary()
	if left == null:
		return null
	while _match(Tok.AND):
		var right := _parse_unary()
		if right == null:
			return null
		left = FormulaRes.new(FormulaRes.Kind.AND, "", left, right)
	return left

## unary := '~' unary | primary
func _parse_unary() -> FormulaRes:
	if _match(Tok.NOT):
		var child := _parse_unary()
		if child == null:
			return null
		return FormulaRes.new(FormulaRes.Kind.NOT, "", child)
	return _parse_primary()

## primary := atom | '(' implication ')'
func _parse_primary() -> FormulaRes:
	var token := _peek()
	if token.type == Tok.ATOM:
		_advance()
		return FormulaRes.new(FormulaRes.Kind.ATOM, token.text)

	if token.type == Tok.LPAREN:
		_advance()
		var inner := _parse_iff()
		if inner == null:
			return null
		var closing := _peek()
		if closing.type != Tok.RPAREN:
			_set_error(
				"expected ')' at position %d, got %s"
				% [closing.position, _token_desc(closing)],
				closing.position
			)
			return null
		_advance()
		return inner

	_set_error(
		"expected formula at position %d, got %s"
		% [token.position, _token_desc(token)],
		token.position
	)
	return null

## Return the current token without consuming it.
func _peek() -> Token:
	if _index < _tokens.size():
		return _tokens[_index]
	return _tokens[_tokens.size() - 1]

## Consume one token, but never move past EOF.
func _advance() -> Token:
	var token := _peek()
	if _index < _tokens.size() - 1:
		_index += 1
	return token

## Consume the expected token type if present.
func _match(expected: Tok) -> bool:
	if _peek().type == expected:
		_advance()
		return true
	return false

## Record the first error encountered.
func _set_error(message: String, position: int) -> void:
	if _error == "":
		_error = message
		_error_position = position

## Describe a token for error messages.
func _token_desc(token: Token) -> String:
	if token.type == Tok.EOF:
		return "end of input"
	return "'" + token.text + "'"

## Whitespace recognized by the lexer.
func _is_whitespace(character: String) -> bool:
	return character == " " or character == "\t" or character == "\n" or character == "\r"
