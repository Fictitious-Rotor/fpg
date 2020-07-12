local function makeRxMatcher(regexPattern)
  return patternNoWhitespace(function(strIdx, parsed)
    local value = (strIdx:getValue() or ""):match(regexPattern)
    
    if value then
      return strIdx:withFollowingIndex(), cons(value, parsed)
    else
      return false
    end
  end)
end

Whitespace = makeRxMatcher("%s")
           * "Whitespace"

Alphabetic = makeRxMatcher("[%a_]")
           * "Alphabetic"
--
Digit = makeRxMatcher("%d")
      * "Digit"
--
Alphanumeric = makeRxMatcher("[%w_]")
             * "Alphanumeric"
--

local keywordExports = {
  kw_do = kw "do",
	kw_if = kw "if",
	kw_in = kw "in",
	kw_or = kw "or",
	kw_end = kw "end",
	kw_for = kw "for",
	kw_nil = kw "nil",
	kw_and = kw "and",
	kw_not = kw "not",
	kw_else = kw "else",
	kw_goto = kw "goto",
	kw_then = kw "then",
	kw_true = kw "true",
	kw_while = kw "while",
	kw_until = kw "until",
	kw_local = kw "local",
	kw_break = kw "break",
	kw_false = kw "false",
	kw_repeat = kw "repeat",
	kw_elseif = kw "elseif",
	kw_return = kw "return",
	kw_function = kw "function"
}

kw_multiline_close = sym "]]"
kw_multiline_open = sym "[["
kw_bracket_close = sym "]"
kw_bracket_open = sym "["
kw_label_delim = sym "::"
kw_brace_close = sym "}"
kw_paren_close = sym ")"
kw_speech_mark = sym '"'
kw_ellipsis = sym "..."
kw_paren_open = sym "("
kw_backslash = sym "\\"
kw_brace_open = sym "{"
kw_are_equal = sym "=="
kw_not_equal = sym "~="
kw_semicolon = sym ";"
kw_concat = sym ".."
kw_equals = sym "="
kw_divide = sym "/"
kw_modulo = sym "%"
kw_caret = sym "^"
kw_comma = sym ","
kw_colon = sym ":"
kw_minus = sym "-"
kw_quote = sym "'"
kw_times = sym "*"
kw_hash = sym "#"
kw_plus = sym "+"
kw_lte = sym "<="
kw_gte = sym ">="
kw_dot = sym "."
kw_lt = sym "<"
kw_gt = sym ">"


return keywordExports