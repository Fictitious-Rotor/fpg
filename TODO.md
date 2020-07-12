#TODO

Add something that allows you to freely amend `pattern`s.
Add a function to pattern that allows you to amend it.
For example:
`expr:amend(function(expr) return expr / my_custom_expr end)`
It'd then shift the original value for `expr` into an upvalue, replacing the value at `expr` with whatever is returned from the function.
Check to see if any uses of 'pattern' should have been `definition`

Add tests for numbers
Add NaN keyword. Add it to Number.

Implement comments & multiline comments as more eBNF.
