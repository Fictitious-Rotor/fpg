local tokeniser = require "tokeniser"
local parser = assert(dofile("../../Common/Parser.lua"))
local view = assert(dofile("../../debugview.lua"))

local aString = "if programWorks then print('Congratulations!') end"

print("Lexed string:", view(tokeniser.lex(aString)))