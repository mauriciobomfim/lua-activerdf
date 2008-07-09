local tostring = tostring
local type = type
local tonumber = tonumber
local oldstring = string
local string = activerdf.string
local activerdf = activerdf
local getmetatable = getmetatable
local setmetatable = setmetatable

module "activerdf"

Literal = {}

Namespace.register ('xsd', 'http://www.w3.org/2001/XMLSchema#')

function Literal.xsd_type(self)
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

function Literal.typed(value, _type)	
	local XSD = activerdf.XSD
	if _type == XSD.string then
		return tostring(value)
	--when XSD::date
	--DateTime.parse(value)
	elseif _type == XSD.boolean then
		return value == 'true' or value == 1
	elseif _type == XSD.integer then		
		return tonumber(value)
	end
end

function Literal.to_ntriple(self)	
	if activerdf_without_xsdtype then
      return '"'..tostring(self)..'"'
	else
      return '"'..tostring(self)..'"^^'..tostring(Literal.xsd_type(self))
	end  
end

--class String; include Literal; end
local strmt = getmetatable(oldstring)
if strmt then	
	if strmt.__index then
		setmetatable(strmt.__index, { __index = Literal })
	else
		strmt.__index = Literal
	end
else
	setmetatable(oldstring, { __index = Literal })
end

--class Integer; include Literal; end
--class DateTime; include Literal; end
--class Date; include Literal; end
--class Time; include Literal; end
--class TrueClass; include Literal; end
--class FalseClass; include Literal; end

LocalizedString = oo.class({}, Literal)

--  attr_reader :lang
function LocalizedString:__init(value, lang)	
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

function LocalizedString:to_ntriple()
	if self.lang then
		return '"'..tostring(self)..'"@'..self.lang
	else
		return self
	end
end

function LocalizedString:to_ntriple()
	if self.lang then
		return '"'..tostring(self)..'"@'..self.lang
	else
		return self
	end
end

function LocalizedString:__tostring()
	return tostring(self.value)
end