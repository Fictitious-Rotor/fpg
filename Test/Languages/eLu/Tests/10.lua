local limbs = { 
    { name = "Leg", count = 32 }, 
    { name = "Arm", count = 16 }, 
    { name = "Tail", count = 0.1 }, 
    { name = "Leg", length = 31 }
}

local function map(fun, tbl)
    local out = {}

    for i,v in ipairs(tbl) do
        out[#out + 1] = fun(v)
    end
    
    return out
end

local function map!(fun, tbl)
    for i, v in ipairs(tbl) do
        tbl[i] = fun(v)
    end
end

local function function?(itm)
    return itm 
       and type(itm) == "function"
end

local function table?(itm)
    return itm 
       and type(itm) == "table"
end

local function arm?(itm)
    return table?(itm)
       and itm.name == "Arm"
end

local function calculateLimbMatches(limbTbl, [matcher arm?])
    return map(matcher, limbTbl)
end

print("Demo", map!(fn(limb) limb == "Arm" choose { 'Arm innit' } else limb end, 
                   { 'Cost', 'me', 'an', 'arm', 'and', 'a', 'leg' }))

return contract calculateLimbMatches(limbTbl:table?, [matcher:function?])