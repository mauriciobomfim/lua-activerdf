local tostring = tostring
local type = type
local oo = activerdf.oo
local RDFS = activerdf.RDFS
local table = activerdf.table
local string = string 
---------------------------------------------------------------------
--- Translates abstract query into SPARQL that can be executed on SPARQL-compliant data source.
-- @release $Id$
---------------------------------------------------------------------
module "activerdf.Query2SPARQL"

Engines_With_Keyword = {'yars2', 'virtuoso'}

--- translates abstract query into SPARQL.
-- @param query a instance of Query.
-- @return a SPARQL query string.
function translate(query)
	local str = ""	
	if query._select then
		local distinct = query._distinct and "DISTINCT " or ""
		
		local select_clauses = table.map(query.select_clauses, function(i,s) return construct_clause(s) end)
 
		str = str .. "SELECT "..distinct..table.concat(select_clauses, ' ').." "
		str = str .. "WHERE { "..where_clauses(query).." "..filter_clauses(query).."} "
		
		if query.limits then
			str = str .. "LIMIT "..query.limits
		end
		if query.offsets then
			str = str .. "OFFSET "..query.offsets
		end
	elseif query._ask then
		str = str .. "ASK { "..where_clauses(query).." }"
	end
		
	return str
end

-- concatenate filters in query.
function filter_clauses(query)
	if query.filter_clauses and not table.empty(query.filter_clauses) then			
		return "FILTER ("..table.concat(query.filter_clauses, " && ")..")"
	end
	return ""
end


-- concatenate each where clause using space (e.g. 's p o')
-- and concatenate the clauses using dot, e.g. 's p o . s2 p2 o2 .'
function where_clauses(query)	
	if query.keyword then
		if sparql_engine() == 'yars2' then
			table.foreach(query.keywords, function(term, keyword)
				query:where(term, keyword_predicate(), keyword)
			end)
		elseif sparql_engine() == 'virtuoso' then
			table.foreach(query.keywords, function(term, keyword)
				query:filter(keyword_predicate.."("..construct_clause(term)..", '"..keyword.."')")
			end)
		end
	end
	
	local where_clauses = table.map(query.where_clauses, function(i,v)
		local s, p, o, c = v[1], v[2], v[3], v[4]
		
		-- does there where clause use a context ? 
		if not c then
			return table.concat(table.map({s, p, o}, function(index, term) return construct_clause(term) end), ' ')
		else
			return "GRAPH "..construct_clause(c).." { "..construct_clause(s).." "..construct_clause(p).." "..construct_clause(o).." }"
		end
	end)
	
	return table.concat(where_clauses, ' . ').." ."
	
end

function construct_clause(term)	
	if type(term) == "string" and string.find(term, "^?") then		
		return tostring(term)
	elseif oo.instanceof(term, RDFS.Resource) then
		return term:to_ntriple()
	elseif type(term) == "number" then
		return Literal.to_ntriple(term)
	else		
		return tostring(term)
	end
end

function sparql_engine()
	local sparql_adapters = table.select(ConnectionPool.read_adapters, function(index, adp) return oo.instanceof(adp, SparqlAdapter) end)
	local engines = table.uniq(table.map(sparql_adapters, function(index, adp) return adp.engine end))

   if not table.all(engines, function(index, eng) return table.include(Engines_With_Keyword, eng) end) then		
		error("one or more of the specified SPARQL engines do not support keyword queries")
   end

   if table.getn(engines) > 1 then		
		error("we currently only support keyword queries for one type of SPARQL engine (e.g. Yars2 or Virtuoso) at a time")
   end
	
	return engines[1]
end

function keyword_predicate()
	if sparql_engine() == 'yars' or sparql_engine() == 'yars2' then
		return RDFS.Resource("http://sw.deri.org/2004/06/yars#keyword")
	elseif sparql_engine() == 'virtuoso' then 
		VirtuosoBIF("bif:contains")
	else		
		error("default SPARQL does not support keyword queries, remove the keyword clause or specify the type of SPARQL engine used")
	end
end
	
--  private_class_method :where_clauses, :construct_clause, :keyword_predicate, :sparql_engine

-- treat virtuoso built-ins slightly different: they are URIs but without <> 
-- surrounding them
VirtuosoBIF = oo.class({}, RDFS.Resource)

function VirtuosoBIF:__tostring()
	return self.uri
end
