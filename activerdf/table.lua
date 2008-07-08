local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable
local table = table
local type = type
local unpack = unpack
local next = next
local getmetatable = getmetatable

module "activerdf.table"

index = function(tbl, value)
	local t = {}
	table.foreach(tbl, function (i,v) 
					t[v] = t[v] or i
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

intersection = function (a,b)
 	
	local Set = {}
    
    function Set.new (t)
      local set = {}
      for _, l in ipairs(t) do set[l] = true end
      return set
    end
    
    local set_a = Set.new(a)
    local set_b = Set.new(b)
    
    function Set.intersection (a,b)
      local res = Set.new{}
      for k in pairs(a) do
        res[k] = b[k]
      end
      return res
    end
 	
 	local res = {}
 	local int = Set.intersection(set_a,set_b)
 	
 	foreach(int, function(i,v) insert(res, i) end)
 	
 	return res
 	 	    
end

difference = function (a, b)
	return reject(a, function(i,v) return include(b, v) end)
end

inject = function (init, t, func)	
	local actual_pos
	local next_pos
	local acc
	local func = func
	local t = t
	
	if type(func) == "function" then
		acc = init
		next_pos = next(t)
	else
		func = t
		t = init		
		actual_pos = next(t)
		next_pos = next(t, actual_pos)
		acc = t[actual_pos]		
	end
	
	while t[next_pos] do
		acc = func(acc, t[next_pos])
		actual_pos = next_pos
		next_pos = next(t, actual_pos)
	end
	
	return acc
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
	table.foreach(tbl, function(i,v) table.insert(set, t[v]) end)			
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
	local r = table.foreachi(tbl, function(i,v) if value == v then return true end end)
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
	for _,v in pairs(t) do			
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
  return f
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