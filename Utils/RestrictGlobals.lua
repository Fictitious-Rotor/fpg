local lib = {}

local function errorOnIndex(tbl, key)
  error(string.format("Missing global variable with key: '%s'", key))
end

local function errorIfNotDeclared(tbl, key, val)
  rawset(tbl, key, val == true or error "Cannot reference a global without prior declaration")
end

function lib.enable()
  local oldMeta = getmetatable(_G) or {}

  oldMeta.__index = errorOnIndex
  oldMeta.__newindex = errorIfNotDeclared
  
  setmetatable(_G, oldMeta)
end

function lib.disable()
  local oldMeta = getmetatable(_G) or {}

  oldMeta.__index = nil
  oldMeta.__newindex = nil
  
  setmetatable(_G, oldMeta)
end

return lib