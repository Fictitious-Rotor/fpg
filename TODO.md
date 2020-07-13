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

Add support for caching. If something matches as a name and I'm looking for Name a second time at the same point then just jump ahead. I shouldn't have to look a second time.

Debugging through a raw log is pretty gory. Add some form of utility that allows me to actually see what the program is getting up to.
I could use [the following library](http://wxlua.sourceforge.net/)
I could redo the `*` operator to make it into a debug reflection device, showing the actual layout of patterns and how they fit together.
The debug tool would render these as a tree on my screen and would also show a chain of the decisions taken. I should be able to choose a pattern and a position arbitrarily.
I should also be able to randomly choose an entry in the history chain, which will take the program back to that step, moving the caret back there as well.
I should also be able to see a panel containing say 8 lines of the input, with a bright caret moving through it as I step through the program.
I should also be able to put down breakpoints on a particular position in the tree, asking the program to run through all the preceding patterns until it reaches the chosen one.
