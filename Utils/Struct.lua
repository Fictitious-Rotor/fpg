local function Struct(structName)
  local structMeta = {
    __tostring = function(self)
      local outTable = {}
      
      for k, v in pairs(self) do
        local strV = type(v) == "string" and string.format("'%s'", v) or tostring(v)
      
        outTable[#outTable + 1] = string.format("'%s' = %s", k, tostring(strV))
      end
      
      return string.format("'%s' = { %s }", structName, table.concat(outTable, ", "))
    end
  }

  return function(propertyNames)
    return function(...)
      local theStruct = {}
      local args = { ... }
      
      for idx, propertyName in ipairs(propertyNames) do
        theStruct[propertyName] = args[idx]
      end
      
      return setmetatable(theStruct, structMeta)
    end
  end
end

return Struct