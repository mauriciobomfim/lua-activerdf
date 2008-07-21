---------------------------------------------------------------------
--- Extends the default lua table functions. 
-- @release $Id$
---------------------------------------------------------------------

local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable
local table = table
local type = type
local unpack = unpack
local next = next
local getmetatable = getmetatable

module "activerdf.table"

-- Returns the key (field name) for a given value. If not found, returns <code>nil</code>.
-- @usage <code>
-- h = { a = 100, b = 200 }<br>
-- table.index(h, 200)   --> "b"
-- talbe.index(h, 999)   --> nil  
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

--- returns a table with the intersection of <em>a</em> and <em>b</em>.
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

--- returns a table with the difference of <em>a</em> and <em>b</em>.
difference = function (a, b)
	return reject(a, function(i,v) return include(b, v) end)
end

--- combines the elements of <em>tbl</em> by applying the function func to an accumulator value (<em>memo</em>) and each <em>element</em> in turn.
-- At each step, <em>memo</em> is set to the value returned by the function func. 
-- You can supply an initial value for <em>memo</em> using the parameter <em>init</em>. 
-- If <em>init</em> is ommited it uses the first element of the table as a the initial value (and skips that element while iterating). 
-- @param init initial value for <em>memo</em>.
-- @param tbl a table.
-- @param func <code>function( memo, element ) ... end</code>
-- @usage <code>
-- -- Sum some numbers<br>
-- table.inject ( {1,2,3}, function(sum, n) return sum + n end ) --> 6<br><br>
-- -- Multiply some numbers<br>
-- table.inject (1, {1,2,3,4}, function(product, n) return product * n end ) --> 24<br>
-- <br>
-- -- Multiple tables intersection<br>
-- t = {{1,2,3}, {2,3}, {3,4}}<br>
-- table.inject( t, function( intersec, n ) return table.intersection(intersec, n) end ) --> { 3 }
-- </code>
inject = function (init, tbl, func)	
	local actual_pos
	local next_pos
	local acc
	local func = func
	local t = tbl
	
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

--- equality of two tables.
-- Tables are equal if they each contain the same number of fields and if each field-value pair is equal to (according to ==) the corresponding elements in the other table.
-- @usage <code>
--	h1 = { a = 1, c = 2 }<br>
--	h2 = { [7] = 35, c = 2, a = 1 }<br>
--	h3 = { a = 1, c = 2, [7] = 35 }<br>
--	h4 = { a = 1, d = 2, f = 35 }<br>
--	table.equals ( h1, h2 ) --> false<br>
--	table.equals ( h2, h3 ) --> true<br>
--	table.equals ( h3, h4 ) --> false<br>
-- </code>
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

--- returns a new table populated with the keys (fields) from this table. 
-- @usage <code>h = { a = 100, b = 200, c = 300, d = 400 }
-- <br>table.keys(h) --> { "a", "b", "c", "d" }</code>
keys = function(tbl)
	local t = {}
	table.foreach(tbl, function (i,v)
					table.insert(t, i)
				 end)
	return t
end

--- concatenation — returns a new table built by concatenating the two tables together to produce a third table.
-- @usage <code>table.add( { 1, 2, 3 } , { 4, 5 } )    --> { 1, 2, 3, 4, 5 }</code>
add = function(tbl1, tbl2)
	local tbl = {}
	table.foreach(tbl1, function(i,v) table.insert(tbl, v) end)
	table.foreach(tbl2, function(i,v) table.insert(tbl, v) end)
	return tbl
end

--- returns a new table by removing duplicate values in <em>tbl</em>.
-- @usage <code>a = { "a", "a", "b", "b", "c" }<br>
-- table.uniq(a)   --> { "a", "b", "c" }</code>
uniq = function(tbl)
	local t = {}
	local set = {}
	table.foreach(tbl, function(i,v) t[v] = v end)
	table.foreach(tbl, function(i,v) table.insert(set, t[v]) end)			
	return set
end

--- passes each element of the table to the given function and returns <code>true</code> if the function ever returns a value other that <code>false</code> or <code>nil</code>.
-- If the function is not given, it adds an implicit <code>function(i,v) return v end</code>.
-- That is, table.any will return <code>true</code> if at least one of the <em>tbl</em> members is not <code>false</code> or <code>nil</code>. 
any = function(tbl, func)
	local func = func or function(i,v) return v end
	return table.foreach(tbl, func)
end

--- passes each element of the table to the given function and returns <code>true</code> if the function never returns <code>false</code> or <code>nil</code>.
-- If the function is not given, it adds an implicit <code>function(i,obj) return obj end</code>. 
-- That is, table.all will return <code>true</code> only if none of the <em>tbl</em> members are <code>false</code> or <code>nil</code>. 
all = function(tbl, func)
	local func = func or function(i,obj) return obj end		
	return table.getn(map(tbl, func)) == table.getn(tbl)
end

--- returns <code>true</code> if the given <em>value</em> is present in <em>tbl</em>.
-- That is, if any element == value, false otherwise. 
-- @usage <code>
-- a = { "a", "b", "c" }<br>
-- table.include(a, "b")   --> true<br>
-- table.include(a, "z")   --> false
-- </code>
include = function(tbl, value)
	local r = table.foreachi(tbl, function(i,v) if value == v then return true end end)
	return r or false
end

--- invokes <em>func</em> once for each element of self. 
-- Creates a new table containing the values returned by the function.
-- @usage <code>
-- a = { "a", "b", "c", "d" }<br>
-- table.map ( a, function(i, x) return  x .. "!" end)   --> { "a!", "b!", "c!", "d!" }<br>
-- a --> { "a", "b", "c", "d" }
-- </code>
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

--- invokes the function <em>func</em> passing in successive elements from table, returning a table containing those elements for which the function returns a <code>true</code> value. 
-- @usage <code>
-- a = { 'a', 'b', 'c', 'd', 'e', 'f' }<br>
-- table.select ( a, function(i,v) return string.find(v, "[aeiou]") end )   --> { "a", "e" }
-- </code>
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

--- returns a new table containing the items in <em>self</em> for which the function <em>func</em> is not <code>true</code>. 
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

--- returns a new table that is a one-dimensional flattening of this table (recursively). 
-- That is, for every element that is a table, extract its elements into the new table. 
-- @usage <code>
-- s = { 1, 2, 3 }           --> { 1, 2, 3 }<br>
-- t = { 4, 5, 6, { 7, 8 } } --> { 4, 5, 6, { 7, 8 } }<br>
-- a = { s, t, 9, 10 }       --> { { 1, 2, 3 }, { 4, 5, 6, { 7, 8 } }, 9, 10 }<br>
-- a = table.flatten(a)      --> { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
-- </code>
function flatten(tbl)
  local f = { }
  __flatten(tbl,f,true)  
  return f
end

--- produces a shallow copy of table <em>tbl</em>.
-- The elements of <em>tbl</em> are copied, but not the inside table references.
-- @usage <code>
-- a = { 1, 2, 3 }<br>
-- b = table.dup(a)<br>
-- table.equals(a, b) --> true <br>
-- print(a) --> table: 0032B850 <br>
-- print(b) --> table: 0032BA18
-- </code>
function dup(tbl)
	local t = {}
	table.foreach(tbl, function(i,v) t[i] = v end)
	return t
end

--- returns <code>true</code> if <em>tbl</em> table contains no elements.
-- @usage <code> table.empty({})   --> true</code> 
function empty(tbl)
	local result = table.foreach(tbl, function(i,v) return true end)
	return not (result or false)
end

setmetatable(_M, {__index = table})