---------------------------------------------------------------------
--- Extends the default lua string functions. 
-- @release $Id$
---------------------------------------------------------------------

local string = string
local setmetatable = setmetatable
local table = activerdf.table

module "activerdf.string"

--- divides <em>str</em> into substrings based on a delimiter (pattern), returning an table of these substrings. 
-- <br>
-- @param str input string.
-- @param pattern pattern delimiter.
-- @usage <code>string.split(" now's the time", " ") 	--> { "now's", "the", "time" }</code>
-- @usage <code>string.split("1, 2.34,56, 7", "[,%s]+")	--> { "1", "2.34", "56", "7" }</code>
-- @usage <code>string.split("mellow yellow", "ello"	--> { "m", "w y", "w" }</code>
-- @usage <code>string.split("1,2,,3,4,,", ",")			--> { "1", "2", "", "3", "4" }</code>
function split(str, pattern)
	local str = str
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pattern
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

--- returns a copy of <em>str</em> with the first character converted to uppercase and the remainder to lowercase. 
function capitalize(str)
	local result = string.gsub (str, "(%w+)", function(a) return  string.upper(string.sub(a,1,1)) .. string.sub(a,2) end)
	return result
end
--- returns a new string with the last character removed. 
-- If the string ends with \r\n, both characters are removed. Applying chop to an empty string returns an empty string. 
-- <code>string.chomp</code> is often a safer alternative, as it leaves the string unchanged if it doesn’t end in a record separator. 
function chop(str)
	if str:sub(-2,-1) == "\r\n" then
		return str:sub(1, -3)
	end
	return str:sub(1, -2)
end

setmetatable(_M, { __index = string })