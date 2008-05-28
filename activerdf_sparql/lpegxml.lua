--[[

Copyright (c) 2006 Michael Wolf

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

--]]

module("activerdf_sparql.SparqlAdapter.lpegxml",package.seeall)
local DEBUG=false

function parse(xmlstr)
	local stack={}
	local top={}
	table.insert(stack,top)

	local function argumenttable(...)
		local arguments={...}
		local args
		
		if #arguments>0 then 
			args={}
			for i=1,#arguments,2 do
				args[arguments[i]]=arguments[i+1]
			end
		end
		return args
	end
	
	local function open(label,...)
		if DEBUG then print("open",label,...) io.flush() end
		top = {label=label,args=argumenttable(...)}
		table.insert(stack, top)
	end

	local function close(label)
		if DEBUG then print("close",label,stack[#stack].label) io.flush() end
		local toclose = table.remove(stack)  -- remove top
		top = stack[#stack]
		table.insert(top, toclose)
	end

	local function single(label,...)
		if DEBUG then print("single",label) io.flush() end
		open(label,...)
		close(label)
	end

	local function text(txt)
		if DEBUG then print("text",'#'..txt..'#') end
		table.insert(top,txt)
	end

	local function cdata(txt)
		if DEBUG then print("cdata",'#'..txt..'#') end
		table.insert(top,txt)
	end

	local function comment(txt)
		if DEBUG then print("comment",'#'..txt..'#') end
		if not top.comment then top.comment={} end
		top.comment[#top.comment+1]=txt
	end

	local function declaration(name,...)
		if DEBUG then print("declaration",...) io.flush() end
		if not top.declaration then top.declaration={} end
		top.declaration[name]=argumenttable(...)
	end

	local lt=lpeg.P('<')
	local gt=lpeg.P('>')
	local apos=lpeg.P('"')
	local equal=lpeg.P("=")
	local space=lpeg.P(" ")
	local slash=lpeg.P("/")
	local space=lpeg.S(" \t\r\n")
	local letter=lpeg.R("az", "AZ")
	local namecharstart=letter + '_' + ':'
	local name=namecharstart * (namecharstart + lpeg.R("09") + lpeg.P('-'))^0
	local content=(lpeg.P(1) - lt)^1
	local comment_open=lpeg.P("<!--")
	local comment_close=lpeg.P("-->")
	local cdata_start=lpeg.P("<![CDATA[")
	local cdata_end=lpeg.P("]]>")

	local declaration=(space^0 * lpeg.P('<?') * lpeg.C(name) * 
		(space^1 * lpeg.C(name) * equal * 
		apos * lpeg.C((lpeg.P(1) -apos)^1) * apos )^1 * 
		space^0 * lpeg.P('?>')) / declaration
		
	local attribute=(space^1 * lpeg.C(name) * space^0 * equal * space^0 * 
		apos * lpeg.C((lpeg.P(1) - apos)^0) * apos)
		
	local opening_element=(space^0 * lt * lpeg.C(name) * 
		attribute^0 * space^0 * gt) / open
		
	local closing_element=(space^0 * lt * slash * lpeg.C(name) * gt) / close
	
	local singelton_element=(space^0 * lt * lpeg.C(name) * 
		attribute^0 * space^0 * slash *gt) / single
		
	local content=space^0 * ((lpeg.P(1) - lt)^1) * space^0 / text
	
	local cdata=(space^0 * cdata_start  * 
		lpeg.C((lpeg.P(1) -cdata_end)^1) * cdata_end )/cdata
		
	local comment_element=(space^0 * comment_open * 
		lpeg.C((lpeg.P(1) - comment_close)^0) * comment_close) / comment

	local xml=lpeg.P{
		[1]=declaration^0 * lpeg.V(2),
		[2]=opening_element * lpeg.V(3)^0 * closing_element,
		[3]=comment_element^1 + singelton_element^1 
			+ content + cdata + lpeg.V(2),
	}

	
	if xml:match(xmlstr) then
		return stack[1]
	else
		return nil,"Parse error"
	end
end
	
	
---[==[
--[[	Test	--]]

local xmltbl=assert(parse([=[
<?xml version="1.0" encoding="UTF-8"?>
<recipe name="bread" prep_time="5 mins" cook_time="3 hours">
  <title>Basic bread</title>
  <ingredient amount="3" unit="cups">Flour</ingredient>
  <ingredient amount="0.25" unit="ounce">Yeast</ingredient>
  <ingredient amount="1.5" unit="cups" state="warm">Water</ingredient>
  <ingredient amount="1" unit="teaspoon">Salt</ingredient>
  <instructions>
    <step>Mix all ingredients together, and knead thoroughly.</step>
    <step>Cover with a cloth, and leave for one hour in warm room.</step>
    <step>Knead again, place in a tin, and then bake in the oven.</step>
  </instructions>
</recipe>]=]))

local function printxmltbl(tbl,lvl)
	lvl=lvl or 0
	for k,v in pairs(tbl) do
		if type(k)~='number' then 
			if type(v)=='table' then
				io.write(string.rep("\t",lvl),k,"={\n")
				printxmltbl(v,lvl+1)
				io.write(string.rep("\t",lvl),"},\n")
			else
				io.write(string.rep("\t",lvl),k,'="',tostring(v),'",\n')
			end
		end
	end
	for k,v in ipairs(tbl) do
		if type(v)=='table' then
			io.write(string.rep("\t",lvl),"{\n")
			printxmltbl(v,lvl+1)
			io.write(string.rep("\t",lvl),"},\n")
		else
			io.write(string.rep("\t",lvl),'"',tostring(v),'",\n')
		end
	end
end

--]==]
return activerdf_sparql.SparqlAdapter.lpegxml