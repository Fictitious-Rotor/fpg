local parse = require("parser").parseString

local theFile = io.open("../tests/TestState.lua", "r")

local theContent = theFile:read("*all")
theFile:close()

local parsed = parse(theContent)
print("theContent == parsed:", theContent == parsed)

local outFileName = "parsedTestState.lua"
local outFile = io.open(outFileName, "w")

outFile:write(parsed)
outFile:close()
print("Written to:", outFileName)
