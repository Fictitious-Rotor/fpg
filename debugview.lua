return function(givenObject, showNumericKeys)
  local strTbl = {}
  
  function isTable(arg)
    return type(arg) == "table"
  end
  
  function ensureTable(arg)
    return type(arg) == "table" and arg or { arg }
  end
  
  function unpackTbl(tbl)
    local contentFound = false
  
    strTbl[#strTbl + 1] = '{'
    
    for k, v in pairs(tbl) do
      if showNumericKeys or type(k) ~= "number" then
        strTbl[#strTbl + 1] = type(k) == "string" and "'" .. k .. "'" or tostring(k)
        strTbl[#strTbl + 1] = '='
      end
      
      if isTable(v) then
        unpackTbl(v)
      else
        strTbl[#strTbl + 1] = type(v) == "string" and "'" .. v .. "'" or tostring(v)
      end
      strTbl[#strTbl + 1] = ','
      contentFound = true
    end
    
    strTbl[#strTbl + (contentFound and 0 or 1)] = '}' -- Overwrites last comma if present
  end
  
  if isTable(givenObject) then
    unpackTbl(givenObject)
  else
    strTbl[#strTbl + 1] = tostring(givenObject)
  end

  return table.concat(strTbl)
end