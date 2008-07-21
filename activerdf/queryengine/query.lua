---------------------------------------------------------------------
-- Represents a query on a datasource, abstract representation of SPARQL features. 
-- Query is passed to federation manager or adapter for execution on data source. 
-- <br>In all clauses, strings starting with ? represent variables:
-- <br><br><code>Query.new():select('?s'):where('?s','?p','?o')</code>.
-- @release $Id$
-- LUADOC COMMENTS ARE AT END OF THIS FILE
---------------------------------------------------------------------
require 'activerdf.federation.federation_manager'

local type = type
local unpack = unpack
local tostring = tostring
local tonumber = tonumber
local pairs = pairs
local error = error
local module = module

module "activerdf"

Query = oo.class{}

--- creates a new Query.
-- @name new
function Query.new()
	return Query()
end

function Query:__init()  
	return oo.rawnew(self, { 
		_distinct = false,
		limit = nil,
		offset = nil,
		select_clauses = {},
		where_clauses = {},
		sort_clauses = {},
		filter_clauses = {},
		keywords = {},
		reasoning = true,
		reverse_sort_clauses = {},
	})
end


--- clears the select clauses.
-- @name clear_select
function  Query:clear_select()
	-- $activerdflog.debug "cleared select clause"
	self.select_clauses = {}
	self._distinct = false
end

--- adds variables to select clause.
-- @name select
-- @param an arbitrary list of arguments.
-- @usage <code>q:select('?s', '?p')</code>
function Query:select(...)
	local s = {...}
	self._select = true
	table.foreach(s, function(index, e)
		table.insert(self.select_clauses, self:parametrise(e))
	end)
	-- removing duplicate select clauses
	table.uniq(self.select_clauses)
	return self
end

--- adds variables to ask clause (see SPARQL specification).
-- @name ask
function Query:ask()
	self._ask = true
	return self
end

--- adds variables to select distinct clause.
-- @name distinct
-- @usage <code>q:distinct('?s', '?p')</code>
function Query:distinct(...)	
	self._distinct = true	
	return self:select(...)		
end

Query.select_distinct = Query.distinct

--- adds variables to count clause.
-- @name count
function Query:count(...)	
	self._count = true
	return self:select(...)
end

--- adds sort predicates.
-- @name sort
function Query:sort(...)
	-- add sort clauses without duplicates
	local s = {...}
	table.foreach(s, function(index, clause) table.insert(self.sort_clauses, self:parametrise(clause)) end)
	table.uniq(self.sort_clauses)
	return self
end

--- adds one or more generic filters.
-- NOTE: you have to use SPARQL syntax for variables, eg. ('?s', 'abc').
-- @name filter
function Query:filter(...)
	local s = {...}
	-- add filter clauses
	table.insert(self.filter_clauses, s)
	table.uniq(self.filter_clauses)
	return self
end

--- adds regular expression filter on one variable.
-- @name filter_regexp
-- @param variable a string that appears in select/where clause
-- @param regex a string used as regular expression.
function Query:filter_regexp(variable, regexp)	
	if not (type(variable) == 'string') then
		error("variable must be a string")
	end
		
	if not (type(regexp) == string) then
		error("regexp must be a regular expression string")	
	end
	
	return self:filter ([[regex(str(?]]..variable..[[), ]]..regexp:gsub('/','"')..[[)]])
end

Query.filter_regex = Query.filter_regexp

--- adds operator filter one one variable.
-- @name filter_operator
-- @param variable a string that appears in select/where clause
-- @param operator a SPARQL operator (e.g. '>')
-- @param operand a SPARQL value (e.g. 15)
function Query:filter_operator(variable, operator, operand)	
	if not (type(variable) == 'string') then
		error("variable must be a string")
	end

	return self:filter ("?"..variable.." "..operator.." "..operand)
end

--- filter variable on specified language tag.
-- Optionally matches exactly on language dialect, otherwise only 
-- language-specifier is considered.
-- @name lang
-- @param variable a SPARQL variable
-- @param tag a language tag
-- @param exact true or false. If not specified, the default is false.
-- @usage <code>q:lang('?o', 'en')</code>
function Query:lang(variable, tag, exact)
	local exact = exact or false
	if exact then
		return self:filter("lang(?"..variable..") = '"..tag.."'")						
	else
		return self:filter("regex(lang(?"..variable.."), '^"..tag:gsub('_.*', '').."$')")				
	end
end

--- adds reverse sorting predicates.
-- @name reverse_sort
function Query:reverse_sort(...)
	local s = {...}
	-- add sort clauses without duplicates
	table.foreach(s, function(index,clause) table.insert(self.reverse_sort_clauses, self:parametrise(clause)) end)
	table.uniq(self.reverse_sort_clauses)
	return self
end

--- adds limit clause (maximum number of results to return).
-- @name limit
function Query:limit(number)
	self.limits = tonumber(number)
	return self
end

--- adds offset clause (ignore first n results).
-- @name offset
function Query:offset(number)
	self.offsets = tonumber(number)
	return self
end

--- adds where clauses (s,p,o) where each constituent is either variable ('?s') or an RDFS.Resource. 
-- Keyword queries are specified with the special '?keyword' string.
-- <br><br><code>Query.new():select('?s'):where('?s', '?keyword', 'eyal')<code>
-- @name where
-- @param s subject
-- @param p predicate
-- @param o object
-- @param c 
function Query:where(s,p,o,c)
	if p == '?keyword' then
		-- treat keywords in where-clauses specially
		self:keyword_where(s,o)
	else
		-- remove duplicate variable bindings, e.g.
		-- where(:s,type,:o).where(:s,type,:oo) we should remove the second clause, 
		-- since it doesn't add anything to the query and confuses the query 
		-- generator. 
		-- if you construct this query manually, you shouldn't! if your select 
		-- variable happens to be in one of the removed clauses: tough luck.
			
		if not ( oo.instanceof(s, RDFS.Resource) or oo.subclassof(s, RDFS.Resource) or (type(s) == 'string') ) then			
			error ("cannot add a where clause with s "..tostring(s)..": s must be a resource or a variable")
		end
		if not ( oo.instanceof(s, RDFS.Resource) or oo.subclassof(s, RDFS.Resource) or (type(s) == 'string') ) then			
			error ("cannot add a where clause with p "..tostring(p)..": p must be a resource or a variable")
		end
		table.insert(self.where_clauses, table.map({s,p,o,c}, function(index, arg) return self:parametrise(arg) end))
	end
	return self
end

-- adds keyword constraint to the query. You can use all Ferret query syntax in 
-- the constraint (e.g. keyword_where('?s','eyal|benjamin')
function Query:keyword_where(s,o)
	self.keyword = true
	local s = self:parametrise(s)
	if self.keywords[s] then
		self.keywords[s] = self.keywords[s]..' '..tostring(o)
	else
		self.keywords[s] = tostring(o)
	end
	return self
end

--- executes query on data sources. Either returns result as a table indexed numerically
-- (flattened into single value unless specified otherwise)
-- or executes a function (number of function parameters should be
-- same as number of select variables)
-- @name execute
-- @param options e.g 'flatten'
-- @param func a function
-- @usage <code>results = query:execute()</code>
-- @usage <code>query:execute ( nil, function(s,p,o) ... end )
function Query:execute(options, func)
	if not options then
		options = { flatten = false }
	end	
	if options == 'flatten' then
		options = {flatten = true} 
	end
	
	if type(func) == 'function' then		
		for index, result in pairs(FederationManager.query(self, options)) do
			return func(unpack(result))
		end
	else		
		return FederationManager.query(self, options)
	end
end

-- Returns query string depending on adapter (e.g. SPARQL, N3QL, etc.)
function Query:__tostring()
	if not ConnectionPool.read_adapters()[1] then		
		return self:inspect()
	else				
		return ConnectionPool.read_adapters()[1]:translate(self)
	end
end

--- Returns SPARQL serialisation of query.
-- @name to_sp
function Query:to_sp()
	require 'activerdf.queryengine.query2sparql'
	return Query2SPARQL.translate(self)
end

--  private
function Query:parametrise(s)		
	if ( type(s) == 'string' and (string.sub(s,1,1) == '?' or string.find(s, '<(.*)>') ) )
		or oo.instanceof(s, RDFS.Resource)
		or oo.instanceof(s, Literal)
		or oo.isclass(s)
	then
		return s
	elseif s == nil then
		return nil
	elseif type(s) == 'number' then
		return Literal.to_ntriple(s)
	else
		return '"'..tostring(s)..'"'
	end
end

function Query:inspect(old)
	local str = ""	
	table.foreach(self, function(i,v)
		if type(i) == 'string' then
			str = str..i.." = "
		end
		if type(v) == 'table' then
			str = str.."{"
			str = str..Query.inspect(v, true)
			str = str.."}, "
		else
			str = str..tostring(v)..", "
		end
	end)
	if not old then
		str = "Query={ "..str.."}"
	end
	return str
end

-- it is here just because of luadoc
---------------------------------------------------------------------
--- Represents a query on a datasource, abstract representation of SPARQL features. 
-- Query is passed to federation manager or adapter for execution on data source. 
-- <br>In all clauses, strings starting with ? represent variables:
-- <br><br><code>Query.new():select('?s'):where('?s','?p','?o')</code>.
-- @release $Id$
---------------------------------------------------------------------
module 'activerdf.Query'