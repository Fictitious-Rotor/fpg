local StringIndex = {}

StringIndex.__index = StringIndex

function StringIndex.new(tbl, idx) 
  return setmetatable({ tbl = tbl, idx = idx }, StringIndex)
end

function StringIndex:withIndex(newIdx)
  return StringIndex.new(self.tbl, newIdx)
end

function StringIndex:withFollowingIndex()
  return StringIndex.new(self.tbl, self.idx + 1)
end

function StringIndex:getTable()
  return self.tbl
end

function StringIndex:getIndex()
  return self.idx
end

function StringIndex:getValue(givenIdx)
  return self.tbl[givenIdx or self.idx]
end

function StringIndex:__tostring()
  return "position: " .. self.idx
end

return StringIndex
