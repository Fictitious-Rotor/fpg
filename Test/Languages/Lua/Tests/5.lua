local strIdx = {}
function strIdx:getValue() return 'no' end
while strIdx:getValue(idx) == ' ' do 
  idx = idx + 1
end