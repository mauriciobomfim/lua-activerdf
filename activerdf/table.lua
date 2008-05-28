local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable
local table = table
local type = type
local unpack = unpack
local print = print

module "activerdf.table"

index = function(tbl, value)
	local t = {}
	table.foreach(tbl, function (i,v) 
					t[v] = i
				 end)
	if type(value) == 'table' then
		table.foreach(t, function(i,v)
			if equals(i, value) then
				value = i
				return
			end
		end)
	end
	return t[value]
end

equals = function(tbl1, tbl2)	
	local result = table.foreach(tbl1, function(i,v)
		if tbl1[i] ~= tbl2[i] then
			return true
		end
	end)
	if empty(tbl1) then
		return empty(tbl2)
	end
	return not (result and true)
end

keys = function(tbl, value)
	local t = {}
	table.foreach(tbl, function (i,v)
					table.insert(t, i)
				 end)
	return t
end

add = function(tbl1, tbl2)
	local tbl = {}
	table.foreach(tbl1, function(i,v) table.insert(tbl, v) end)
	table.foreach(tbl2, function(i,v) table.insert(tbl, v) end)
	return tbl
end

uniq = function(tbl)
	local t = {}
	local set = {}
	table.foreach(tbl, function(i,v) t[v] = v end)
	table.foreach(t, function(i,v) table.insert(set, v) end)			
	return set
end

any = function(tbl, func)
	local func = func or function(i,v) return v end
	return table.foreach(tbl, func)
end

all = function(tbl, func)
	local func = func or function(i,v) return v end		
	return table.getn(map(tbl, func)) == table.getn(tbl)
end

include = function(tbl, value)
	local r = table.foreachi(tbl, function(i,v) if v == value then return true end end)
	return r or false
end

function map(self, func, ...)
	local args = {...}
	local R = {}	
	local insert_value
	for name,value in pairs(self) do 
		insert_value = func(name,value,unpack(args))		
		if insert_value then			
			table.insert(R, insert_value)
		end
	end	
	return R
end

function select(self, func, ...)
  local R = {}
	local insert_value
	for name,value in pairs(self) do 
		insert_value = func(name,value,unpack(arg))
		if insert_value then
			table.insert(R, value)
		end
	end
	return R
end

function reject(self, func, ...)
  local R = {}
	local insert_value
	for name,value in pairs(self) do 
		insert_value = func(name,value,unpack(arg))
		if not insert_value then
			table.insert(R, value)
		end
	end
	return R
end

function __flatten(t,f,complete)
	for _,v in ipairs(t) do	
		if type(v) == "table" then		
			 if (complete or type(v[1]) == "table") then
				  __flatten(v,f,complete)				  				  
			 else
				  f[#f+1] = v				  
			 end
		else			
			 f[#f+1] = v
		end
	end
end

function flatten(t)
  local f = { }
  __flatten(t,f,true)  
  return t
end


function dup(tbl)
	local t = {}
	table.foreach(tbl, function(i,v) t[i] = v end)
	return t
end

function empty(tbl)	
	local result = table.foreach(tbl, function(i,v) return true end)
	return not (result or false)
end

setmetatable(_M, {__index = table})