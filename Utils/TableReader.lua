local TableReader = {}

TableReader.__index = TableReader

function TableReader.new(tbl, idx) 
  return setmetatable({ tbl = tbl, idx = idx or 1 }, TableReader)
end

function TableReader:withIndex(newIdx)
  return TableReader.new(self.tbl, newIdx)
end

function TableReader:withFollowingIndex()
  return TableReader.new(self.tbl, self.idx + 1)
end

function TableReader:getTable()
  return self.tbl
end

function TableReader:getIndex()
  return self.idx
end

function TableReader:getValue(givenIdx)
  return self.tbl[givenIdx or self.idx]
end

function TableReader:__tostring()
  return "position: " .. self.idx
end

return TableReader
