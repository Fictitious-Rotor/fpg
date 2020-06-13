local StringIndex = {
  __tostring = table.concat,
  getTable = function(instance) return instance.tbl end,
  getIndex = function(instance) return instance.idx end
}

StringIndex.__index = StringIndex

return function(tbl, idx)
  return setmetatable({ tbl = tbl, idx = idx }, StringIndex)
end