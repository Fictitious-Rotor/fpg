#TODO

Add something that allows you to freely amend `keywords` and `symbols`.

Make all keywords inherit from `pattern`.

Add a function to pattern that allows you to amend it.
For example:
`expr:amend(function(expr) return expr / my_custom_expr end)`
It'd then shift the original value for `expr` into an upvalue, replacing the value at `expr` with whatever is returned from the function.

Ensure that globals defined in a file will automatically be reachable from any file that calls it.
Look into a way to have a file specific global.

Check to see if any uses of 'pattern' should have been `definition`
