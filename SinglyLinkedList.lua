local List = {}

List.__index = List

List.null = setmetatable({ head = false, tail = false }, List)

function List.cons(head, tail)
  return setmetatable({ head = head, tail = tail }, List)
end

function List.getHead(tbl)
  return tbl.head
end

function List.getTail(tbl)
  return tbl.tail
end

local function setValue(val, tbl, idx)
  tbl[idx] = val
  return tbl, idx + 1
end

-- Deepest value first, top value last.
function List.__tostring(instance)
  function loop(tbl)
    local head = tbl:getHead()
  
    if not head then
       return {}, 1
    else
      return setValue(head, loop(tbl:getTail()))
    end
  end
  
  local tbl, _ = loop(instance)
  
  return table.concat(tbl, " ")
end

return List