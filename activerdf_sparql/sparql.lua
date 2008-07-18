require 'activerdf.federation.activerdf_adapter'

local oo = activerdf.oo

local http = require 'socket.http'
local require = require
local type = type
local tostring = tostring
local error = error
local ltn12 = ltn12
local table = activerdf.table

local ConnectionPool = activerdf.ConnectionPool
local Query2SPARQL = activerdf.Query2SPARQL
local RDFS = activerdf.RDFS
local BNode = activerdf.BNode
local ActiveRdfAdapter = activerdf.ActiveRdfAdapter

----------------------------------------------------------------------------
-- URL-encode a string (see RFC 2396)
----------------------------------------------------------------------------
local function escape (str)
	str = string.gsub (str, "\n", "\r\n")
	str = string.gsub (str, "([^%w ])",
		function (c) return string.format ("%%%02X", string.byte(c)) end)
	str = string.gsub (str, " ", "+")
	return str
end

module "activerdf_sparql"

-- SPARQL adapter
SparqlAdapter = oo.class({}, ActiveRdfAdapter)

--$activerdflog.info "loading SPARQL adapter"
ConnectionPool.register_adapter('sparql', SparqlAdapter)

SparqlAdapter.sparql_cache = {}

function SparqlAdapter.get_cache()
	return SparqlAdapter.sparql_cache
end
	
-- Instantiate the connection with the SPARQL Endpoint.
-- available parameters:
-- * url = url: endpoint location e.g. "http://m3pe.org:8080/repositories/test-people"
-- * results = one of 'xml', 'json', 'sparql_xml'
-- * request_method = 'get' (default) or 'post'
-- * timeout = timeout in seconds to wait for endpoint response
function SparqlAdapter.new(...)
	return SparqlAdapter(...)
end

function SparqlAdapter:__init(params)
	params = params or {}
	
	local obj =  oo.rawnew(self, {
		class = 'SparqlAdapter',
		reads = true,
		writes = false,
		url = params['url'] or '',
		caching = params['caching'] or false,
		timeout = params['timeout'] or 50,
		result_format = params['results'] or 'json',			 	
		engine = params['engine'],		
		request_method = params['request_method'] or 'get'		
	})	
	
	if not table.include({'xml', 'json', 'sparql_xml'}, obj.result_format ) then		
		error "Result format unsupported"
	end
	
	if not table.include({ 'yars2', 'sesame2', 'joseki', 'virtuoso'}, obj.engine) then		
		error "SPARQL engine unsupported"
	end
		
	if not table.include({'get', 'post'}, obj.request_method) then		
		error "Request method unsupported"
	end

	return obj  

end


function SparqlAdapter:size()
	return table.getn(self:query(Query():select('?s','?p','?o'):where('?s','?p','?o')))
end

-- query datastore with query string (SPARQL), returns array with query results
-- may be called with a block
function SparqlAdapter:query(query, block)	
	local qs = Query2SPARQL.translate(query)
	local result
	
	if self.caching then
		result = self:query_cache(qs)
      if not result then
         -- $activerdflog.debug "cache miss for query #{qs}"
      else
		 -- $activerdflog.debug "cache hit for query #{qs}"
		 return result
      end
	end

	result = self:execute_sparql_query(qs, self:header(query), block)
	
	if self.caching then
		self:add_to_cache(qs, result)
	end
	
	if result == "timeout" then
		result = {}
	end
	
	return result
end
	
-- do the real work of executing the sparql query
function SparqlAdapter:execute_sparql_query(qs, header, block)
	if header == nil then
		local header = self:header(nil)
	end

	-- querying sparql endpoint		
	local response = ''
	local t_response = {}
	local url
	local res_request = nil
	local err = nil
	
	http.TIMEOUT = self.timeout
	
	if self.request_method == 'get' then
		-- encoding query string in URL      
		url = self.url.."?query="..escape(qs)
      -- $activerdflog.debug "GET #{url}"
		res_request, err = http.request({ url = url, sink = ltn12.sink.table(t_response), redirect = true, headers = header })
	elseif self.request_method == 'post' then
		--$activerdflog.debug "POST #@url with #{qs}"
      res_request, err = http.request({ url = url, sink = ltn12.sink.table(t_response), redirect = true, headers = header, method = 'post' })
    end
	
	if err == "timeout" then		
		-- raise ActiveRdfError, "timeout on SPARQL endpoint"
		-- error "timeout on SPARQL endpoint"
		return "timeout"				
	end

	if res_request then		
		response = table.concat(t_response)
	else	
	
	--rescue Timeout::Error
	--	raise ActiveRdfError, "timeout on SPARQL endpoint"
  	--return "timeout"
	--rescue OpenURI::HTTPError => e
	--	raise ActiveRdfError, "could not query SPARQL endpoint, server said: #{e}"
	--	return []
	--rescue Errno::ECONNREFUSED
	--	raise ActiveRdfError, "connection refused on SPARQL endpoint #@url"
	--	return []
		error(err)
		return {}
	end
	
	-- we parse content depending on the result format
	local results
	if self.result_format == 'json' then
		results = self:parse_json(response)
	elseif self.result_format == 'xml' or self.result_format == 'sparql_xml' then
		results = self:parse_xml(response)
	end
	
	if type(block) == 'function' then
		table.foreach(results, function(index, clauses)
			return block(unpack(clauses))		
		end)
	else		
		return results
	end
end
	
	
function SparqlAdapter:close()
	return ConnectionPool.remove_data_source(self)
end
	
-- private

function SparqlAdapter:add_to_cache(query_string, result)	
	if result and ( (type(result) == 'string' and result ~= "") or ( type(result) == 'table' and not table.empty(result) ) ) then
		if result == "timeout" then			
			SparqlAdapter.sparql_cache[query_string] = {}
		else 
			--$activerdflog.debug "adding to sparql cache - query: #{query_string}"
			SparqlAdapter.sparql_cache[query_string] = result
		end
	 end
end

function SparqlAdapter:query_cache(query_string)
	return SparqlAdapter.sparql_cache[query_string]
end


-- constructs correct HTTP header for selected query-result format
function SparqlAdapter:header(query)
	if self.result_format == 'json' then
		return { accept = 'application/sparql-results+json' }
	elseif self.result_format == 'xml' then
		return { accept = 'application/rdf+xml' }
	elseif self.result_format == 'sparql_xml' then
		return { accept = 'application/sparql-results+xml' }
	end
end

-- parse json query results into array
function SparqlAdapter:parse_json(s)
	
	local JSON = require 'json'   	
	local parsed_object = JSON.decode(s)
   
	if type(parsed_object) ~= 'table' or table.empty(parsed_object) then		
		return {}
	end   
   
	local vars = parsed_object['head']['vars']
	local objects = parsed_object['results']['bindings']
	
	return self:parse_table_results(vars, objects)

end
  
-- parse xml stream result into array
function SparqlAdapter:parse_xml(s)
	
	local lpeg = require 'lpeg'
	local lpegxml = require 'activerdf_sparql.lpegxml'
	local parsed_object = lpegxml.parse(s)
	
	if type(parsed_object) ~= 'table' or table.empty(parsed_object) then		
		return {}
	end
	
	local vars = {}
	table.foreachi(parsed_object[1][1], function(i,v) if v.args then table.insert (vars, v.args.name) end end)
	local objects = {}
	table.foreachi(parsed_object[1][2], function(i,v) if v.args then table.insert(objects, { [v[1].args.name] = { type = v[1][1].label , value = v[1][1][1] } } ) end end)
		
	return self:parse_table_results(vars, objects)
end

function SparqlAdapter:parse_table_results(vars, objects)
	local results = {}
	local vars = vars or {}
	local objects = objects or {}
	
	table.foreach(objects, function(index, obj)
		local result = {}
		table.foreach(vars, function(i,v)
			table.insert(result, self:create_node( obj[v]['type'], obj[v]['value']))			
		end)
		table.insert(results, result)
	end)
	
	return results
end
  
-- create LOOP objects for each RDF node
function SparqlAdapter:create_node(_type, value)
	if _type == 'uri' then    
      return RDFS.Resource(value)
	elseif _type == 'bnode' then
      return BNode(value)
   elseif _type == 'literal' or _type == 'typed-literal' then
		return tostring(value)
   end  
end
