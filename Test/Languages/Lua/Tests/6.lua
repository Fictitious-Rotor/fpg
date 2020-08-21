local strIdx, idx = { getValue = function() return ' ' end }, 1

while strIdx:getValue(idx) == ' ' do 
  idx = idx + 1
end