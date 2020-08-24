local luaLang = require "fpg.Languages.Lua.bootstrap"
local view = require "fpg.Utils.debugview"

local function readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

-- For some bizarre reason lua lacks a directory list function?
-- I can either use shell commands, depend on a c library or hardcode the range.
-- I've chosen the latter as it's the most portable.
for testNo = 1, 9 do
  local testFileContents = readAll(string.format("./Tests/%s.lua", testNo))
  
  local output = luaLang(testFileContents)
  -- Doesn't evaluate yet.
  -- Can't easily verify the tokens as some of them were removed (Whitespace & Comments)
  assert(output, string.format("Output for test number #%s failed to parse correctly", testNo))
end

print("All tests parsed correctly")