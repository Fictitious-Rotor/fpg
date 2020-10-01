#TODO

Debugging through a raw log is pretty gory. Add some form of utility that allows me to actually see what the program is getting up to.
I could use [the following library](http://wxlua.sourceforge.net/)
The debug tool would render the ebnf as a tree on my screen and would also show a chain of the decisions taken. I should be able to choose a pattern and a position arbitrarily.
I should also be able to randomly choose an entry in the history chain, which will take the program back to that step, moving the caret back there as well.
I should also be able to see a panel containing say 8 lines of the input, with a bright caret moving through it as I step through the program.
I should also be able to put down breakpoints on a particular position in the tree, asking the program to run through all the preceding patterns until it reaches the chosen one.



eLu language spec:
	add '!' & '?' as possible characters in an identifier
	add 'contract' as a new keyword.
		contract functionName(arg1:pred1, arg2:pred2, [arg3:pred3], [arg4])
		Is an expression. Intended for use only in interfaces.
	add default arguments to functions
		function functionName(arg1, arg2, [arg3 default1], [arg4 default2])
	add lambda syntax
		fn(args) body... tail end
		returns tail
		supports default arguments feature
	add proper iif support
		expr choose val1, val2
			   else default1, default2
	match syntax? (not yet)
	make it so that assignments return the value that was assigned
	add wrapper function for d{ Name, ":", Name }
	some sort of lua equivalent to log-once