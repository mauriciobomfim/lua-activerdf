local string = string
local setmetatable = setmetatable
local table = activerdf.table

module "activerdf.string"

function split(self, pat)
	local str = self
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

function capitalize(self)
	local result = string.gsub (self, "(%w+)", function(a) return  string.upper(string.sub(a,1,1)) .. string.sub(a,2) end)
	return result
end

function chop(self)
	if self:sub(-2,-1) == "\r\n" then
		return self:sub(1, -3)
	end
	return self:sub(1, -2)
end

setmetatable(_M, { __index = string })