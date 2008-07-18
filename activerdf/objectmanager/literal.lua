---------------------------------------------------------------------
--- Represents an RDF literal, optionally datatyped.
-- @release $Id$
---------------------------------------------------------------------
local tostring = tostring
local type = type
local tonumber = tonumber
local oldstring = string
local string = activerdf.string
local activerdf = activerdf
local getmetatable = getmetatable
local setmetatable = setmetatable
local Namespace = activerdf.Namespace
local oo = activerdf.oo
local module = module
local activerdf = activerdf

module 'activerdf.Literal'

Namespace.register ('xsd', 'http://www.w3.org/2001/XMLSchema#')

--- returns the resource representing the XML Schema datatype of a literal.
function xsd_type(self)
	local XSD = activerdf.XSD
	if type(self) == 'string' then
		return XSD.string
	elseif type(self) == 'number' then	
		return XSD.integer
	elseif type(self) == 'boolean' then
		return XSD.boolean
	--when DateTime, Date, Time
	--XSD::date
	end 
end

--- converts the literal to a lua type for the datatype.
-- @param datatype a resource representing a datatype.
function typed(value, datatype)	
	local XSD = activerdf.XSD
	if datatype == XSD.string then
		return tostring(value)
	--when XSD::date
	--DateTime.parse(value)
	elseif datatype == XSD.boolean then
		return value == 'true' or value == 1
	elseif datatype == XSD.integer then		
		return tonumber(value)
	end
end

--- returns the literal on ntriple format
function to_ntriple(self)	
	if activerdf_without_xsdtype then
      return '"'..tostring(self)..'"'
	else
      return '"'..tostring(self)..'"^^'..tostring(xsd_type(self))
	end  
end

--class String; include Literal; end
local strmt = getmetatable(oldstring)
if strmt then	
	if strmt.__index then
		setmetatable(strmt.__index, { __index = _M })
	else
		strmt.__index = _M
	end
else
	setmetatable(oldstring, { __index = _M })
end

--class Integer; include Literal; end
--class DateTime; include Literal; end
--class Date; include Literal; end
--class Time; include Literal; end
--class TrueClass; include Literal; end
--class FalseClass; include Literal; end

activerdf.LocalizedString = oo.class({}, Literal)

--  attr_reader :lang
function activerdf.LocalizedString:__init(value, lang)	
	local l = lang
	local v = value
	if string.sub(l, 1,1) == '@' then
		l = string.sub(l, 2,-1)
	end

	return oo.rawnew(self, { 
		value = v,
		lang = l
	})
end

function activerdf.LocalizedString:to_ntriple()
	if self.lang then
		return '"'..tostring(self)..'"@'..self.lang
	else
		return self
	end
end

function activerdf.LocalizedString:__tostring()
	return tostring(self.value)
end